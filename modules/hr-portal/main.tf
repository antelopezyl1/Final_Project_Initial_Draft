locals {
  project_name = "HR-Portal"  
  tags = {
    Project     = local.project_name
    Environment = var.environment
  }
}

