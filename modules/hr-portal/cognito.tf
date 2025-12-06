#resource "aws_cognito_user_pool" "pool_primary" {
#  name = "zylpool-primary"
#}

#resource "aws_cognito_user_pool_client" "client_primary" {
#  name                                 = "client-primary"
#  user_pool_id                         = aws_cognito_user_pool.pool_primary.id
#  callback_urls                        = ["http://${aws_lb.alb_primary.dns_name}/oauth2/idpresponse"]
#  logout_urls                          = ["http://${aws_lb.alb_primary.dns_name}/"]
#  allowed_oauth_flows_user_pool_client = true
#  allowed_oauth_flows                  = ["code"]
# allowed_oauth_scopes                 = ["email", "openid", "profile"]
#  supported_identity_providers         = ["COGNITO"]
#  generate_secret     = true
#}

#resource "aws_cognito_user_pool_domain" "domain_primary" {
#  domain       = "zylpool-primary"
#  user_pool_id = aws_cognito_user_pool.pool_primary.id
#}

#resource "aws_cognito_user_pool" "pool_standby" {
#  name = "zylpool-standby"
#}

#resource "aws_cognito_user_pool_client" "client_standby" {
#  name                                 = "client-standby"
#  user_pool_id                         = aws_cognito_user_pool.pool_standby.id
#  callback_urls                        = ["http://${aws_lb.alb_standby.dns_name}/oauth2/idpresponse"]
#  logout_urls                          = ["http://${aws_lb.alb_.dns_name}/"]
#  allowed_oauth_flows_user_pool_client = true
#  allowed_oauth_flows                  = ["code"]
#  allowed_oauth_scopes                 = ["email", "openid", "profile"]
#  supported_identity_providers         = ["COGNITO"]
#  generate_secret     = true
#}

#resource "aws_cognito_user_pool_domain" "domain_standby" {
#  domain       = "zylpool-standby"
#  user_pool_id = aws_cognito_user_pool.pool_standby.id
#}