
module "vpc_primary" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc-primary"
  cidr = "172.16.0.0/16"


  azs              = ["us-west-1a", "us-west-1c"]
  private_subnets  = ["172.16.101.0/24", "172.16.201.0/24"]
  public_subnets   = ["172.16.102.0/24", "172.16.202.0/24"]
  database_subnets = ["172.16.103.0/24", "172.16.203.0/24"]

  map_public_ip_on_launch = true

  create_igw = true

  single_nat_gateway = true
  enable_nat_gateway = true
}

module "vpc_standby" {
  source = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.standby
  }

  name = "my-vpc-standby"
  cidr = "10.16.0.0/16"


  azs              = ["us-west-2a", "us-west-2b"]
  private_subnets  = ["10.16.101.0/24", "10.16.201.0/24"]
  public_subnets   = ["10.16.102.0/24", "10.16.202.0/24"]
  database_subnets = ["10.16.103.0/24", "10.16.203.0/24"]

  map_public_ip_on_launch = true

  create_igw = true

  single_nat_gateway = true
  enable_nat_gateway = true

}

output "vpc_primary_id" {
  value = module.vpc_primary.vpc_id
}

output "vpc_standby_id" {
  value = module.vpc_standby.vpc_id
}

locals {
  primary_vpc_id = module.vpc_primary.vpc_id
  standby_vpc_id = module.vpc_standby.vpc_id
}

resource "aws_security_group" "allow_egress_primary" {
  name        = "allow-egress-primary"
  description = "Allow all outbound traffic in primary vpc"
  vpc_id      = local.primary_vpc_id

  tags = {
    Name = "allow_egress_primary"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_primary" {
  security_group_id = aws_security_group.allow_egress_primary.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_security_group" "allow_egress_standby" {
  provider    = aws.standby
  name        = "allow-egress-standby"
  description = "Allow all outbound traffic in standby vpc"
  vpc_id      = local.standby_vpc_id

  tags = {
    Name = "allow-egress-standby"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_standby" {
  provider          = aws.standby
  security_group_id = aws_security_group.allow_egress_standby.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_security_group" "allow_ssh_primary" {
  name        = "allow-ssh-primary"
  description = "Allow all inbound ssh traffic in primary vpc"
  vpc_id      = local.primary_vpc_id

  tags = {
    Name = "allow-ssh-primary"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_primary" {
  security_group_id = aws_security_group.allow_ssh_primary.id
  from_port         = 22
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_security_group" "allow_ssh_standby" {
  provider    = aws.standby
  name        = "allow-ssh-standby"
  description = "Allow all inbound ssh traffic in standby vpc"
  vpc_id      = local.standby_vpc_id

  tags = {
    Name = "allow-ssh-standby"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_standby" {
  provider          = aws.standby
  security_group_id = aws_security_group.allow_ssh_standby.id
  from_port         = 22
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  to_port           = 22
}

#bastion ec2 sg
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "SSH from anywhere; egress all"
  vpc_id      = local.primary_vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_in_any" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_out" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc_primary.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.key_pair_primary.key_name
  associate_public_ip_address = true
  tags                        = { Name = "bastion-primary" }
}