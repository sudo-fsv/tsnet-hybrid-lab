#########################################################
# Outputs
#########################################################

output "vpc_server_id" {
  value = module.vpc_server.vpc_id
}

output "vpc_client_id" {
  value = module.vpc_client.vpc_id
}

output "client_vm_id" {
  value = aws_instance.client_vm.id
}

output "eks_cluster_name" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = data.aws_eks_cluster.cluster.endpoint
}

output "client_vm_private_ip" {
  value = aws_instance.client_vm.private_ip
}

output "client_vm_public_ip" {
  value = aws_instance.client_vm.public_ip
}

output "tailscale_subnet_router_ips" {
  value = var.tailscale_subnet_router_enable ? aws_instance.tailscale_subnet_router[*].public_ip : []
}
