terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # This config's OWN state can stay local (or in a separate
  # already-existing bucket). It's the one piece of Terraform
  # state you don't bootstrap with itself.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "terraform-state-backend"
      ManagedBy = "terraform"
    }
  }
}
