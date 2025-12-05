terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-1"

  default_tags {
    tags = {
      Project     = "HR-Portal"
      Environment = "prod"
      Owner       = "yuling-zang"
    }
  }
}

provider "aws" {
  alias  = "standby"
  region = "us-west-2"
}
