# Terraform Test LSEG
Test Drupal website using Terraform




# Demo
http://prod-web-elb-1212818872.us-east-1.elb.amazonaws.com/



# Architecture
![Logo](https://raw.githubusercontent.com/udithshan/lseg/master/arch.png)


## Deployement Instructions
Before you RUN the main.tf below steps you need to follow,

* Create key name drupal
* Crete a image using the build method you like and pushed it to aws
* Update the AMI id on the main.tf file

```bash
git clone https://github.com/udithshan/lseg.git
Terraform init 
Terraform plan
Terraform apply 
```