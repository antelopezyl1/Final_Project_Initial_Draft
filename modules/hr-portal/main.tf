terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws,
        aws.standby,
      ]
    }
  }
}

locals {
  project_name = "HR-Portal"
  tags = {
    Project     = local.project_name
    Environment = var.environment
  }
}

