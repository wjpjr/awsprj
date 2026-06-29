output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "app_instance_id" {
  value = module.ec2.instance_id
}

output "app_private_ip" {
  value = module.ec2.private_ip
}
