
data "aws_iam_policy_document" "hr_portal_db_secrets_access" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.hr_portal_db.arn]
  }
}

resource "aws_iam_policy" "hr_portal_db_secrets_access" {
  name   = "hr-portal-db-secrets-access"
  policy = data.aws_iam_policy_document.hr_portal_db_secrets_access.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "hr_portal_app_role" {
  name               = "hr-portal-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "hr_portal_secrets_access_attach" {
  role       = aws_iam_role.hr_portal_app_role.name
  policy_arn = aws_iam_policy.hr_portal_db_secrets_access.arn
}

resource "aws_iam_instance_profile" "hr_portal_app_instance_profile" {
  name = "hr-portal-app-instance-profile"
  role = aws_iam_role.hr_portal_app_role.name
}