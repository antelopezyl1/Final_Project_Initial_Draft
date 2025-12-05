resource "aws_security_group" "alb_primary" {
  name        = "alb-primary"
  description = "Allow traffic of 80 port in primary vpc"
  vpc_id      = local.primary_vpc_id

  tags = {
    Name = "alb-primary"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_primary" {
   security_group_id = aws_security_group.alb_primary.id
   from_port         = 80
   cidr_ipv4         = "0.0.0.0/0"
   ip_protocol       = "tcp"
   to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_out_primary" {
  security_group_id = aws_security_group.alb_primary.id
  referenced_security_group_id = aws_security_group.ec2_primary.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_out_to_cognito_primary" {
  security_group_id = aws_security_group.alb_primary.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}


resource "aws_security_group" "ec2_primary" {
  name        = "ec2-primary"
  description = "Allow traffic of 80 port from alb in primary vpc"
  vpc_id      = local.primary_vpc_id

  tags = {
    Name = "ec2-primary"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb_primary" {
   security_group_id = aws_security_group.ec2_primary.id
   referenced_security_group_id = aws_security_group.alb_primary.id
   from_port         = 80
   ip_protocol       = "tcp"
   to_port           = 80
}

resource "aws_security_group" "alb_standby" {
  provider = aws.standby
  name        = "alb-standby"
  description = "Allow traffic of 80 port in standby vpc"
  vpc_id      = local.standby_vpc_id

  tags = {
    Name = "alb-standby"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_standby" {
   provider = aws.standby
   security_group_id = aws_security_group.alb_standby.id
   from_port         = 80
   cidr_ipv4         = "0.0.0.0/0"
   ip_protocol       = "tcp"
   to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_out_standby" {
  provider = aws.standby
  security_group_id = aws_security_group.alb_standby.id
  referenced_security_group_id = aws_security_group.ec2_standby.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_out_to_cognito_standby" {
  provider = aws.standby
  security_group_id = aws_security_group.alb_standby.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_security_group" "ec2_standby" {
  provider = aws.standby
  name        = "ec2-standby"
  description = "Allow traffic of 80 port from alb in standby vpc"
  vpc_id      = local.standby_vpc_id

  tags = {
    Name = "ec2-standby"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb_standby" {
   provider = aws.standby
   security_group_id = aws_security_group.ec2_standby.id
   referenced_security_group_id = aws_security_group.alb_standby.id
   from_port         = 80
   ip_protocol       = "tcp"
   to_port           = 80
}

resource "tls_private_key" "key_primary" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair_primary" {
  key_name   = "key_primary"
  public_key = tls_private_key.key_primary.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.key_primary.private_key_pem}' > ${path.module}/key_primary.pem && chmod 0700 ${path.module}/key_primary.pem"
  }
}

resource "aws_key_pair" "key_pair_standby" {
  provider = aws.standby
  key_name   = "key_standby"
  public_key = tls_private_key.key_primary.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.key_primary.private_key_pem}' > ${path.module}/key_standby.pem && chmod 0700 ${path.module}/key_standby.pem"
  }
}



resource "aws_launch_template" "primary_launch" {
   name_prefix   = "primary-launch-template"
   image_id      = data.aws_ami.ubuntu.id # Image our ec2 instance will use 
   instance_type = "t3.small" # Size of image
   vpc_security_group_ids = [aws_security_group.allow_egress_primary.id, 
                             aws_security_group.ec2_primary.id,
                             aws_security_group.allow_ssh_primary.id]
   key_name  = "key_primary"
   iam_instance_profile = var.instance_profile_name

   user_data = base64encode(templatefile("${path.module}/user_data.sh", {
   is_primary  = true
   db_host   = module.db_primary.db_instance_address  
   db_port   = module.db_primary.db_instance_port
   db_name    = "db_primary"
   db_user    = var.db_user
   db_password= var.db_password    
   site_url    = "http://${aws_lb.alb_primary.dns_name}"      
   }))

 }

 resource "aws_autoscaling_group" "asg_primary" {
   vpc_zone_identifier = module.vpc_primary.private_subnets
   desired_capacity   = 1 # Desired number of ec2 instances in the group
   max_size           = 2 # Maximum number of ec2 instances in the group
   min_size           = 1 # Minimum number of ec2 instances in the group
   target_group_arns       = [aws_lb_target_group.tg_primary.arn]
 
   launch_template {
     id      = aws_launch_template.primary_launch.id
     version = "$Latest"
   }

   instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0   
      instance_warmup        = 90  
    }
   
  }

 }

 resource "aws_launch_template" "standby_launch" {
   provider = aws.standby
   name_prefix   = "standby-launch-template"
   image_id      = data.aws_ami.ubuntu_standby.id # Image our ec2 instance will use 
   instance_type = "t3.small" # Size of image
   
   vpc_security_group_ids = [aws_security_group.allow_egress_standby.id, 
                             aws_security_group.ec2_standby.id,
                             aws_security_group.allow_ssh_standby.id]
   key_name  = "key_standby"

   user_data = base64encode(templatefile("${path.module}/user_data.sh", {
   is_primary  = false 
   db_host   = module.replica_mysql_standby.db_instance_address
   db_port   = module.replica_mysql_standby.db_instance_port
   db_name    = "db_primary"
   db_user    = var.db_user
   db_password= var.db_password         
   site_url    = "http://${aws_lb.alb_standby.dns_name}"
   
   }))
 }

 resource "aws_autoscaling_group" "asg_standby" {
   provider = aws.standby
   vpc_zone_identifier = module.vpc_standby.private_subnets
   desired_capacity   = 1 # Desired number of ec2 instances in the group
   max_size           = 2 # Maximum number of ec2 instances in the group
   min_size           = 1 # Minimum number of ec2 instances in the group
   target_group_arns       = [aws_lb_target_group.tg_standby.arn]
 
   launch_template {
     id      = aws_launch_template.standby_launch.id
     version = "$Latest"
   }

   instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0   
      instance_warmup        = 90  
    }
   
  }
 }

 resource "aws_lb" "alb_primary" {
   
   name               = "alb-primary"
   load_balancer_type = "application"
   subnets            = module.vpc_primary.public_subnets
   security_groups    = [aws_security_group.alb_primary.id]
 }

 resource "aws_lb_target_group" "tg_primary" {
  name        = "tg-primary"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = local.primary_vpc_id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2  # How many times the health check needs to succeed to be considered healthy
    unhealthy_threshold = 2  # How times the healthcheck needs to fail to mark the instance unhealthy and stop serving it traffic
    timeout             = 5
  }
 }

resource "aws_lb_listener" "listener_primary_http" {
  load_balancer_arn = aws_lb.alb_primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_primary.arn
  }
}

#resource "aws_lb_listener_rule" "auth_cognito_primary" {
#  listener_arn = aws_lb_listener.listener_primary_http.arn
#  priority = 1

#  condition {
#    path_pattern { values = ["/*"] }
#  }

#action {
#  type = "authenticate-cognito"

#   authenticate_cognito {
#     user_pool_arn       = aws_cognito_user_pool.pool_primary.arn
#     user_pool_client_id = aws_cognito_user_pool_client.client_primary.id
#     user_pool_domain    = aws_cognito_user_pool_domain.domain_primary.domain
#     on_unauthenticated_request = "authenticate"
#     scope                      = "openid email profile"
#     session_cookie_name        = "AWSELBAuthSessionCookie"
#     session_timeout            = 604800
#   }
# }

#  action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.tg_primary.arn
 # }
#}


resource "aws_lb" "alb_standby" {
   provider = aws.standby
   name               = "alb-standby"
   load_balancer_type = "application"
   subnets            = module.vpc_standby.public_subnets
   security_groups    = [aws_security_group.alb_standby.id]
 }

 resource "aws_lb_target_group" "tg_standby" {
  provider = aws.standby
  name        = "tg-standby"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = local.standby_vpc_id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2  # How many times the health check needs to succeed to be considered healthy
    unhealthy_threshold = 2  # How times the healthcheck needs to fail to mark the instance unhealthy and stop serving it traffic
    timeout             = 5
  }
 }

resource "aws_lb_listener" "listener_standby_http" {
  provider = aws.standby
  load_balancer_arn = aws_lb.alb_standby.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_standby.arn
  }
}

#resource "aws_lb_listener_rule" "auth_cognito_standby" {
#  provider = aws.standby
#  listener_arn = aws_lb_listener.listener_standby_http.arn
#  priority = 1

#  condition {
 #   path_pattern { values = ["/*"] }
#  }

#  action {
#    type = "authenticate-cognito"

 #   authenticate_cognito {
 #     user_pool_arn       = aws_cognito_user_pool.pool_standby.arn
 #     user_pool_client_id = aws_cognito_user_pool_client.client_standby.id
 #     user_pool_domain    = aws_cognito_user_pool_domain.domain_standby.domain
 #     on_unauthenticated_request = "authenticate"
 #     scope                      = "openid email profile"
 #     session_cookie_name        = "AWSELBAuthSessionCookie"
 #     session_timeout            = 604800
 #   }
 # }
#
 # action {
 #   type             = "forward"
 #   target_group_arn = aws_lb_target_group.tg_standby.arn
 # }
#}

  
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "ubuntu_standby" {
  provider = aws.standby
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

output "alb_primary_dns" {
  description = "Public DNS name for the primary ALB (dynamic WordPress site)"
  value       = "http://${aws_lb.alb_primary.dns_name}"
}