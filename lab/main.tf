#########################################################
# VPCs (server and client) using the community VPC module
#########################################################

module "vpc_server" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "server-vpc"
  cidr = "10.10.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_vpn_gateway = false
}

module "vpc_client" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "client-vpc"
  cidr = "10.20.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = ["10.20.1.0/24"]
  private_subnets = []

  enable_nat_gateway = false
  single_nat_gateway = false
  enable_vpn_gateway = false
}

data "aws_availability_zones" "available" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  apply_public_ip = trimspace(data.http.my_ip.response_body)
}

#########################################################
# EKS cluster in server VPC
#########################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                = var.cluster_name
  kubernetes_version  = "1.33"
  subnet_ids      = module.vpc_server.private_subnets
  vpc_id          = module.vpc_server.vpc_id

  endpoint_public_access  = true // lab_only to validate using Helm to install Tailscale Operator
  endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Create a small managed node group
  eks_managed_node_groups = {
    "${var.cluster_name}-node" = {
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 1
      instance_types   = [var.node_instance_type]
      capacity_type    = "SPOT"
      ami_type         = "AL2023_x86_64_STANDARD"
      timeouts = {
        create = "5m"  // lab_only
        update = "5m"  // lab_only
      }

      # This is not required - demonstrates how to pass additional configuration to nodeadm
      # Ref https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
      cloudinit_pre_nodeadm = [
        {
          content_type = "text/x-shellscript"
          content      = <<-EOT
          #!/bin/bash
          set -o errexit
          set -o pipefail
          set -o nounset

          # Install additional packages
          sudo yum -y install iperf3
          sudo yum -y install kubectl
          sudo yum -y install helm
          EOT
        },
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              kubelet:
                config:
                  shutdownGracePeriod: 30s
          EOT
        }
      ]
    }
  }

  tags = {
    Environment = "lab"
  }
}

#########################################################
# Configure Kubernetes and Helm providers using EKS data
#########################################################

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [ module.eks ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [ module.eks ]
}

# Find EC2 instances that belong to the EKS cluster (nodes)
data "aws_instances" "eks_nodes" {
  filter {
    name   = "tag:kubernetes.io/cluster/${module.eks.cluster_name}"
    values = ["owned"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  filter {
    name   = "subnet-id"
    values = module.vpc_server.private_subnets
  }
  depends_on = [ module.eks ]
}

# Lookup the first EC2 instance to extract its private IP
data "aws_instance" "eks_node" {
  instance_id = element(sort(data.aws_instances.eks_nodes.ids), 0)
  depends_on = [ module.eks ]
}

locals {
  eks_node_ip = length(data.aws_instance.eks_node) > 0 ? data.aws_instance.eks_node.private_ip : ""
  eks_node_ip_fqdn = length(data.aws_instance.eks_node) > 0 ? data.aws_instance.eks_node.private_dns : ""
  pod_subnet_cidrs = module.vpc_server.private_subnets_cidr_blocks
}

#########################################################
# Install Tailscale Operator via Helm (in cluster)
#########################################################

resource "kubernetes_namespace_v1" "tailscale" {
  metadata {
    name = "tailscale"
  }
  depends_on = [ module.eks, aws_instance.tailscale_subnet_router ]
}

resource "helm_release" "tailscale_operator" {
  name = "tailscale-operator"

  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  namespace = kubernetes_namespace_v1.tailscale.metadata[0].name

  set = [
    {
      name  = "oauth.clientId"
      value = var.tailscale_oauth_client_id
    },
    {
      name  = "oauth.clientSecret"
      value = var.tailscale_oauth_client_secret
    },
    {
      name = "operatorConfig.hostname"
      value = "tailscale-operator-eks"
    }
  ]
  depends_on = [ module.eks ]
}

#########################################################
# Deploy a simple hello-world service
#########################################################

resource "kubernetes_deployment_v1" "hello" {
  metadata {
    name      = "hello-deployment"
    namespace = "default"
    labels = { app = "hello" }
  }
  depends_on = [ module.eks ]

  spec {
    replicas = 1
    selector { match_labels = { app = "hello" } }
    template {
      metadata { labels = { app = "hello" } }
      spec {
        container {
          name  = "hello"
          image = "hashicorp/http-echo:1.0.0"
          args  = ["-text=hello from EKS"]
          port { container_port = 5678 }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "hello" {
  metadata {
    name      = "hello-svc"
    namespace = "default"
    annotations = {
      "tailscale.com/expose" = "true",
      "tailscale.com/hostname" = "hello-ts-world"
    }
  }
  depends_on = [ module.eks, helm_release.tailscale_operator ]

  spec {
    selector = { app = kubernetes_deployment_v1.hello.metadata[0].labels.app }
    port {
      port        = 80
      target_port = 5678
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "hello_via_subnet_router" {
  metadata {
    name      = "hello-svc-subnet-router"
    namespace = "default"
  }
  depends_on = [ module.eks, helm_release.tailscale_operator ]

  spec {
    selector = { app = kubernetes_deployment_v1.hello.metadata[0].labels.app }
    port {
      name        = "http"
      port        = 80
      target_port = 5678
      node_port    = 30080
    }
    type = "NodePort"
  }
}

#########################################################
# Client VPC: Ubuntu VM with Tailscale (private subnet + NAT)
#########################################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "client_sg" {
  name        = "client-vm-sg"
  description = "Allow SSH and outbound internet for client VM"
  vpc_id      = module.vpc_client.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.enable_ssh_access ? [format("%s/32", local.apply_public_ip)] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Ubuntu instance in a private subnet so it uses the NAT gateway
resource "aws_instance" "client_vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.client_instance_type
  subnet_id                   = module.vpc_client.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.client_sg.id]
  associate_public_ip_address = true
  key_name                    = "ts-lab-keys"

  user_data = templatefile("${path.module}/tailscale_client_user_data.tpl", {
    tailscale_auth_key = var.tailscale_auth_key
  })

  tags = { Name = "tailscale-client-vm" }
  depends_on = [ module.vpc_client ]
}

#########################################################
# Optional Tailscale subnet router in client's public subnet
#########################################################

resource "aws_instance" "tailscale_subnet_router" {
  count = var.tailscale_subnet_router_enable ? 1 : 0

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.client_instance_type
  subnet_id              = module.vpc_server.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.server_subnet_router_sg.id]
  associate_public_ip_address = true
  key_name                    = "ts-lab-keys"


  user_data = templatefile("${path.module}/tailscale_subnet_router_user_data.tpl", {
    tailscale_auth_key = var.tailscale_auth_key
    pod_routes = join(",", local.pod_subnet_cidrs)
  })

  tags = { Name = "tailscale-subnet-router" }
  depends_on = [ module.vpc_server ]
}

resource "aws_security_group" "server_subnet_router_sg" {
  name        = "server-subnet-router-sg"
  description = "Allow SSH and outbound internet for server subnet router"
  vpc_id      = module.vpc_server.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.enable_ssh_access ? [format("%s/32", local.apply_public_ip)] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "eks_allow_hello_nodeport_from_subnet_router" {
  description       = "Allow access to hello service NodePort from subnet router"
  type              = "ingress"
  from_port         = kubernetes_service_v1.hello_via_subnet_router.spec[0].port[0].node_port
  to_port           = kubernetes_service_v1.hello_via_subnet_router.spec[0].port[0].node_port
  protocol          = "tcp"
  security_group_id = module.eks.node_security_group_id
  cidr_blocks       = module.vpc_server.public_subnets_cidr_blocks

  depends_on = [
    kubernetes_service_v1.hello_via_subnet_router,
    aws_instance.tailscale_subnet_router,
  ]
}
