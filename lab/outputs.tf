output "vpc_server_id" {
  value = module.vpc_server.vpc_id
}

output "vpc_client_id" {
  value = module.vpc_client.vpc_id
}

output "client_vm_id" {
  value = aws_instance.client_vm.id
}
