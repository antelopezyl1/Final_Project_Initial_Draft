
# read shared Secret（
data "aws_secretsmanager_secret" "hr_portal_db" {
  name = "hr-portal-db-credentials"
}

data "aws_secretsmanager_secret_version" "hr_portal_db" {
  secret_id = data.aws_secretsmanager_secret.hr_portal_db.id
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.hr_portal_db.secret_string)
}


module "hr_portal" {
  source = "../../modules/hr-portal"

  environment = "dev"
  region      = "us-west-1"
  db_host = module.rds.db_endpoint
  db_name = "db_intelli_cloud"
  db_user      = local.db_creds.username
  db_password  = local.db_creds.password
  instance_profile_name = "hr-portal-app-instance-profile"

}