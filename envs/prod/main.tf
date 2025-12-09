
data "aws_secretsmanager_secret" "hr_portal_db" {
  name = "hr-portal-db-credentials-v2"
}

data "aws_secretsmanager_secret_version" "hr_portal_db" {
  secret_id = data.aws_secretsmanager_secret.hr_portal_db.id
}


locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.hr_portal_db.secret_string)
}


module "hr_portal" {
  source = "../../modules/hr-portal"
  providers = {
    aws         = aws
    aws.standby = aws.standby
  }

  environment          = "prod"
  db_name              = "db_intelli_cloud"
  db_user              = local.db_creds.db_username
  db_password          = local.db_creds.db_password
  iam_instance_profile = "hr-portal-app-instance-profile"
}
