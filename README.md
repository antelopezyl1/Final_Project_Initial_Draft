# HR Portal - By install WordPress 

# How to deploy
1. Clone the repo
git clone https://github.com/antelopezyl1/Final_Project_Initial_Draft.git
cd  Final_Project_Initial_Draft

2. Deploy AWS infra
terraform init
terraform plan
terraform apply

After apply, Terraform will output similar like:
alb_primary_dns = "http://alb-primary-330731676.us-west-1.elb.amazonaws.com/"
endpoint = "hr-bucket-primary.s3-website-us-west-1.amazonaws.com"
endpoint_standby = "hr-bucket-standby.s3-website-us-west-2.amazonaws.com"
rds_endpoint_primary = "rds-primary.c7is2cqukmqz.us-west-1.rds.amazonaws.com:3306"
replica_endpoint_primary = "rds-replica-primary.c7is2cqukmqz.us-west-1.rds.amazonaws.com:3306"
replica_endpoint_standby = "rds-replica-standby.c3au4q2q00kn.us-west-2.rds.amazonaws.com:3306"
vpc_primary_id = "vpc-058f4a9d95dd1869d"
vpc_standby_id = "vpc-0e4cc6c5d4b12f05b"

3. Upload WordPress HR Portal static website to S3 bucket
aws s3 sync website/ s3://hr-bucket-primary --delete

4. Verify the website: two endpoint for static and dynamic WordPress
Open the ALB DNS name → should show live WordPress
Open the S3 static site URL → should show the static version

5. Docker
docker build -t hr-portal-static .
docker run --rm -p 8080:80 hr-portal-static
Verify:  http://localhost:8080




    
