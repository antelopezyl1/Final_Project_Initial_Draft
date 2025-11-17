# HR Portal - Demo without custom domain

## How to access
1. Run `terraform apply`.
2. Open the URL from Terraform output:
   - Frontend (S3 static site):  http://hr-bucket-primary.s3-website-ap-northeast-1.amazonaws.com
   - Backend (ALB + Cognito):   http://alb-primary-123456789.ap-northeast-1.elb.amazonaws.com
3. The static website will call backend API automatically.
