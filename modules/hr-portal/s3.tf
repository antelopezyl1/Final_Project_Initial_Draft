locals {
  template_dir = "${path.module}/s3-template"

  content_type_map = {
    html  = "text/html"
    css   = "text/css"
    js    = "application/javascript"
    json  = "application/json"
    txt   = "text/plain"
    png   = "image/png"
    jpg   = "image/jpeg"
    jpeg  = "image/jpeg"
    gif   = "image/gif"
    svg   = "image/svg+xml"
    ico   = "image/x-icon"
    webp  = "image/webp"
    woff2 = "font/woff2"
  }
}

resource "aws_s3_bucket" "hr_bucket_primary" {
  bucket = "hr-bucket-primary"
}

resource "aws_s3_object" "template_files" {
  for_each = fileset(local.template_dir, "**")
  bucket   = aws_s3_bucket.hr_bucket_primary.id
  key      = each.value
  source   = "${local.template_dir}/${each.value}"

  content_type = lookup(
    local.content_type_map,
    lower(element(
      reverse(split(".", "${path.module}/s3-template/${each.value}")),
      0
    )),
  "application/octet-stream")

  etag = filemd5("${local.template_dir}/${each.value}")

}

resource "aws_s3_object" "index_primary" {
  bucket = aws_s3_bucket.hr_bucket_primary.id
  key    = "index.html"

  content = templatefile("${path.module}/s3-template/index.html.tpl", {
    apiBase = aws_lb.alb_primary.dns_name
  })

  content_type = "text/html"
}

resource "aws_s3_bucket_website_configuration" "website-config-primary" {
  bucket = aws_s3_bucket.hr_bucket_primary.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

output "endpoint" {
  value = aws_s3_bucket_website_configuration.website-config-primary.website_endpoint
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership_primary" {
  bucket = aws_s3_bucket.hr_bucket_primary.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "hr-bucket-primary" {
  bucket                  = aws_s3_bucket.hr_bucket_primary.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket-policy-primary" {
  bucket = aws_s3_bucket.hr_bucket_primary.id                   # bucket to attach to
  policy = data.aws_iam_policy_document.iam-policy-primary.json # policy to attach
}

data "aws_iam_policy_document" "iam-policy-primary" {
  statement {
    sid       = "AllowS3PublicAccess"
    effect    = "Allow"
    resources = ["${aws_s3_bucket.hr_bucket_primary.arn}/*"] # acesss to the bucket arn and all contents within the bucket arn
    actions   = ["s3:GetObject"]

    principals {
      type        = "*"   # Anyone should be able to access
      identifiers = ["*"] # Should be a list of everything
    }
  }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.hr_bucket_primary.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  bucket = aws_s3_bucket.hr_bucket_primary.id
  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 300
  }
}

resource "aws_s3_bucket" "hr_bucket_standby" {
  provider = aws.standby
  bucket   = "hr-bucket-standby"
}

resource "aws_s3_object" "template_files_standby" {
  provider = aws.standby
  for_each = fileset(local.template_dir, "**")
  bucket   = aws_s3_bucket.hr_bucket_standby.id
  key      = each.value
  source   = "${local.template_dir}/${each.value}"

  content_type = lookup(
    local.content_type_map,
    lower(element(
      reverse(split(".", "${path.module}/s3-template/${each.value}")),
      0
    )),
  "application/octet-stream")

  etag = filemd5("${local.template_dir}/${each.value}")

}

resource "aws_s3_bucket_website_configuration" "website-config-standby" {
  provider = aws.standby
  bucket   = aws_s3_bucket.hr_bucket_standby.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

output "endpoint_standby" {
  value = aws_s3_bucket_website_configuration.website-config-standby.website_endpoint
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership_standby" {
  provider = aws.standby
  bucket   = aws_s3_bucket.hr_bucket_standby.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "hr-bucket-standby" {
  provider                = aws.standby
  bucket                  = aws_s3_bucket.hr_bucket_standby.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket-policy-standby" {
  provider = aws.standby
  bucket   = aws_s3_bucket.hr_bucket_standby.id                   # bucket to attach to
  policy   = data.aws_iam_policy_document.iam-policy-standby.json # policy to attach
}

data "aws_iam_policy_document" "iam-policy-standby" {
  provider = aws.standby
  statement {
    sid    = "AllowS3PublicAccess"
    effect = "Allow"
    resources = [aws_s3_bucket.hr_bucket_standby.arn,
    "${aws_s3_bucket.hr_bucket_standby.arn}/*"] # acesss to the bucket arn and all contents within the bucket arn
    actions = ["s3:GetObject"]

    principals {
      type        = "*"   # Anyone should be able to access
      identifiers = ["*"] # Should be a list of everything
    }
  }
}

resource "aws_s3_bucket_versioning" "standby" {
  provider = aws.standby
  bucket   = aws_s3_bucket.hr_bucket_standby.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_cors_configuration" "this_standby" {
  provider = aws.standby
  bucket   = aws_s3_bucket.hr_bucket_standby.id
  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 300
  }
}

resource "aws_s3_object" "index_standby" {
  provider = aws.standby
  bucket   = aws_s3_bucket.hr_bucket_standby.id
  key      = "index.html"

  content = templatefile("${path.module}/s3-template/index.html.tpl", {
    apiBase = aws_lb.alb_standby.dns_name
  })

  content_type = "text/html"
}