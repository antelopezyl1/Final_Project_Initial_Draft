terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_secretsmanager_secret" "hr_portal_db" {
  name        = "hr-portal-db-credentials-v2"
  description = "Shared DB credentials for HR-Portal (dev & prod)"
}

#resource "aws_secretsmanager_secret_version" "hr_portal_db" {
#  secret_id = aws_secretsmanager_secret.hr_portal_db.id

#  secret_string = jsonencode({
#    username = var.db_username
#    password = var.db_password
#  })
#}

output "hr_portal_db_secret_arn" {
  value       = aws_secretsmanager_secret.hr_portal_db.arn
  description = "ARN of the shared HR-Portal DB credentials secret"
}
