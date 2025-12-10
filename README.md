# HR Portal - By install WordPress 

This project is a fully functional **HR Portal** deployed on AWS using **Terraform**, **WordPress**, and the **WP ERP** HR Management plugin.  
It provides HR features such as employee management, departments, leave tracking, attendance, asset management, and recruitment.

The project demonstrates:
- Cloud infrastructure provisioning (AWS)
- Infrastructure-as-Code (Terraform)
- CI/CD automation (GitHub Actions)
- Deployment of a production-ready HR system

### ✔ CI/CD Pipeline (GitHub Actions)
A lightweight CI pipeline runs on:
- Pull Requests — formatting + validation  
- Push to main — formatting + validation  

⚠️ CI intentionally does **not** modify AWS resources (safe mode), since the final deployment is completed manually.


# How to deploy
##1. Clone the repo
git clone https://github.com/antelopezyl1/Final_Project_Initial_Draft.git
cd  Final_Project_Initial_Draft

##2. Deploy AWS infra
in envs/prod directory:
terraform init
terraform plan
terraform apply   #---the WordPress will be installed and configured automatically in EC2 by executing commands in user_data.sh

##3. Https Access to ALB DNS name + install WP ERP plugin

##4. Set site URL to ALB DNS

##5. HR Portal becomes available publicly


## Docker
docker build -t hr-portal-static .
docker run --rm -p 8080:80 hr-portal-static
Verify:  http://localhost:8080




    
