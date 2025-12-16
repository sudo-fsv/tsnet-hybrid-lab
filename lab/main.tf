terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

#########################################################
# VPCs (server and client) using the community VPC module
#########################################################

module "vpc_server" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "server-vpc"
  cidr = "10.10.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

module "vpc_client" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "client-vpc"
  cidr = "10.20.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnets = ["10.20.11.0/24", "10.20.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false
}

data "aws_availability_zones" "available" {}

#########################################################
# VPC peering
#########################################################

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = module.vpc_server.vpc_id
  peer_vpc_id   = module.vpc_client.vpc_id
  peer_owner_id = data.aws_caller_identity.current.account_id

  tags = {
    Name = "server-client-peering"
  }
}

data "aws_caller_identity" "current" {}

# Routes from server private -> client
resource "aws_route" "server_to_client_private" {
  for_each = toset(module.vpc_server.private_route_table_ids)
  route_table_id         = each.value
  destination_cidr_block = module.vpc_client.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Routes from client private -> server
resource "aws_route" "client_to_server_private" {
  for_each = toset(module.vpc_client.private_route_table_ids)
  route_table_id         = each.value
  destination_cidr_block = module.vpc_server.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

#########################################################
# EKS cluster in server VPC
#########################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"
  subnets         = module.vpc_server.private_subnets_ids
  vpc_id          = module.vpc_server.vpc_id

  manage_aws_auth = true

  # Create a small managed node group
  managed_node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 1
      instance_types   = [var.node_instance_type]
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
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

#########################################################
# Install Tailscale Operator via Helm (in cluster)
#########################################################

resource "helm_release" "tailscale_operator" {
  name       = "tailscale-operator"
  repository = "https://tailscale.github.io/tailscale-operator"
  chart      = "tailscale-operator"
  namespace  = "kube-system"
  create_namespace = false

  depends_on = [module.eks]
}

#########################################################
# Deploy a simple hello-world Deployment + Service
#########################################################

resource "kubernetes_deployment" "hello" {
  metadata {
    name      = "hello-deployment"
    namespace = "default"
    labels = { app = "hello" }
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "hello" } }
    template {
      metadata { labels = { app = "hello" } }
      spec {
        container {
          name  = "hello"
          image = "hashicorp/http-echo:0.2.3"
          args  = ["-text=hello from EKS"]
          port { container_port = 5678 }
        }
      }
    }
  }
}

resource "kubernetes_service" "hello" {
  metadata {
    name      = "hello-svc"
    namespace = "default"
  }

  spec {
    selector = { app = kubernetes_deployment.hello.metadata[0].labels.app }
    port {
      port        = 80
      target_port = 5678
    }
    type = "ClusterIP"
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
    cidr_blocks = var.enable_ssh_access ? ["0.0.0.0/0"] : []
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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.client_instance_type
  subnet_id              = module.vpc_client.private_subnets_ids[0]
  vpc_security_group_ids = [aws_security_group.client_sg.id]

  user_data = templatefile("${path.module}/tailscale_client_user_data.tpl", {
    tailscale_auth_key = var.tailscale_auth_key
  })

  tags = { Name = "tailscale-client-vm" }
}

#########################################################
# Optional Tailscale subnet router in client's public subnet
#########################################################

resource "aws_instance" "tailscale_subnet_router" {
  count = var.tailscale_subnet_router_enable ? 1 : 0

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.client_instance_type
  subnet_id              = module.vpc_client.public_subnets_ids[0]
  vpc_security_group_ids = [aws_security_group.client_sg.id]

  user_data = templatefile("${path.module}/tailscale_subnet_router_user_data.tpl", {
    tailscale_auth_key = var.tailscale_auth_key
    advertise_cidrs    = join(",", module.vpc_client.private_subnets)
  })

  tags = { Name = "tailscale-subnet-router" }
}

#########################################################
# Outputs
#########################################################

output "eks_cluster_name" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = data.aws_eks_cluster.cluster.endpoint
}

output "client_vm_private_ip" {
  value = aws_instance.client_vm.private_ip
}

output "tailscale_subnet_router_ips" {
  value = var.tailscale_subnet_router_enable ? aws_instance.tailscale_subnet_router[*].public_ip : []
}
