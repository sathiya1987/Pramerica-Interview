variable "aws_access_key" { description = "Aws IAM role access key using SAML" }
variable "aws_secret_key" { description = "Aws IAM role secret key using SAML" }
variable "aws_token" { description = "Aws IAM role token using SAML" }
variable "vpc_cidr" { description = "Vpc CIDR block range " default = "192.0.0.0/24" }
variable "vpc_subnet_cidr" { type="list", default = ["192.0.0.32/27", "192.0.0.64/27", "192.0.0.96/27"] }
variable "vpc_subnet_names" { type="list", default = ["prudential-sub-2a", "prudential-sub-2b", "prudential-sub-2c"] }
variable "vpc_subnet_azs" { type="list", default = ["us-west-2a", "us-west-2b", "us-west-2c"] }
variable "instance_type" { description = "AWS Instance Type" default = "t2.micro" }
variable "ami_id" { description = "AMI ID for the EC2 Launch" default = "ami-aa5ebdd2" }
variable "key_name"{description = "key name" default = "sathiya-test"}
