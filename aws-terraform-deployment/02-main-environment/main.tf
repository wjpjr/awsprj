module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
}

module "ec2" {
  source = "./modules/ec2"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  subnet_id        = module.vpc.private_subnet_ids[0]
  instance_type    = var.instance_type
  key_pair_name    = var.key_pair_name
  ssh_allowed_cidr = var.ssh_allowed_cidr
}
