resource "aws_security_group" "db_primary" {
  name        = "db-primary"
  description = "allow traffic from ec2 subnets in primary vpc"
  vpc_id      = local.primary_vpc_id

  tags = {
    Name = "db-primary"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_ec2_primary" {
   security_group_id = aws_security_group.db_primary.id
   referenced_security_group_id = aws_security_group.ec2_primary.id
   from_port         = 3306
   ip_protocol       = "tcp"
   to_port           = 3306
}

resource "aws_security_group" "db_standby" {
  provider = aws.standby
  name        = "db-standby"
  description = "allow traffic from ec2 subnets in standby vpc"
  vpc_id      = local.standby_vpc_id

  tags = {
    Name = "db-standby"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_ec2_standby" {
   provider = aws.standby
   security_group_id = aws_security_group.db_standby.id
   referenced_security_group_id = aws_security_group.ec2_standby.id
   from_port         = 3306
   ip_protocol       = "tcp"
   to_port           = 3306
}


module "db_primary" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "rds-primary"

  engine            = "mysql"
  engine_version    = "8.0"
  major_engine_version = "8.0"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password
  manage_master_user_password = false
  port     = 3306

  multi_az = true
  vpc_security_group_ids = [aws_security_group.db_primary.id]

  backup_retention_period  = 1
  apply_immediately       = true


  # DB subnet group
  create_db_subnet_group = true
  subnet_ids  = module.vpc_primary.database_subnets

  # DB parameter group
  family = "mysql8.0"

  storage_encrypted = true
  kms_key_id        = data.aws_kms_alias.rds_kms_primary.arn

}

output "rds_endpoint_primary" {
  value = module.db_primary.db_instance_endpoint
}

data "aws_kms_alias" "rds_kms_primary" {
  name = "alias/aws/rds"
}

module "replica_mysql_primary" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "rds-replica-primary"

  replicate_source_db = module.db_primary.db_instance_arn

  engine            = "mysql"
  engine_version    = "8.0"
  major_engine_version = "8.0"
  instance_class    = "db.t4g.micro"

  vpc_security_group_ids = [aws_security_group.db_primary.id]


  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = module.vpc_primary.database_subnets

  storage_encrypted = true
  kms_key_id        = data.aws_kms_alias.rds_kms_primary.arn

  family                = "mysql8.0"
  skip_final_snapshot   = true
  deletion_protection   = true

}

output "replica_endpoint_primary" {
  value = module.replica_mysql_primary.db_instance_endpoint
}

data "aws_kms_alias" "rds_kms_standby" {
  provider = aws.standby
  name     = "alias/aws/rds"
}

module "replica_mysql_standby" {

  source = "terraform-aws-modules/rds/aws"
  providers = {
    aws = aws.standby
  }

  identifier = "rds-replica-standby"

  replicate_source_db = module.db_primary.db_instance_arn   #read replica in standby region

  engine            = "mysql"
  engine_version    = "8.0"
  major_engine_version = "8.0"
  instance_class    = "db.t4g.micro"

  vpc_security_group_ids = [aws_security_group.db_standby.id]


  # DB subnet group
   create_db_subnet_group = true
   subnet_ids             = module.vpc_standby.database_subnets

   storage_encrypted = true
  kms_key_id        = data.aws_kms_alias.rds_kms_standby.arn

   # DB parameter group
  family = "mysql8.0"

  skip_final_snapshot = true
  deletion_protection     = true

}

output "replica_endpoint_standby" {
  value = module.replica_mysql_standby.db_instance_endpoint
}