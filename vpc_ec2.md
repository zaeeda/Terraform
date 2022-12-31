Create the IAM user

Go to the Root User of your AWS account.

Go to IAM

 Created the user and made sure I granted the user admin access. I also ensured that I saved the AccessKey ID and Secret Access Key for the user.

Configure User

To configure the user, I made use of Git Bash

The command to configure user: AWS configure

For the input request for the AWS Access Key ID, I entered the access id generated when I created the user.

For the input request for the AWS Shared Access Key, I entered the access key generated when I created the user

For the input request for the Default region name, I used “us-east-1” because this was the region where my user was created.

For the input request for the Default output format [json], I used JSON.

The following steps were taken to create the VPC and also configure it:

get the provider of the resource to be deployed, In my case, I used “AWS” and the region is “us-east-1”. The provider block should be created in the main,tf file in terraform as seen below

 provider "aws" {
  region = "us-east-1"
}

Next, I created the VPC resource block, I created the CIDR block. This will determine the range of IP addresses that can be used by applications in the VPC.  In my case, the cidr_block used is “10.0.0.0/16”. In the vpc resource block, I ensured that I enabled dns_support and dns_hostnames

resource "aws_vpc" "dev-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" #This will be used to give the vpc internal domain name
  enable_dns_hostnames = "true" #This will be used to give the vpc internal host name
  #instance_tenancy     = default #If you put this as true, your ec2 will be he only physical hardwar in AWS

  tags = {
    Name = "dev-vpc"
 

I created a new file called “dev.tfvars” file, this file had the access keys and password to my Aws account. PS: Do not push this to any online account as this grants access to do anything on your AWS account

On the terminal, I ran the command “terraform init” to initialize the working directory and configurations. It also creates the lock file. Below is the output of the terraform init command

Next, i ran the command “terraform plan -out testTF. This runs the execution plan for the terraform file and hence creates the terraform tf state file which is a file that keeps track of all the resources created by my configuration and maps it to real-world resources. You do want to keep your terraform state file safe because every terraform plan that runs, checks the state file first to see if the resource has already been created or not before it creates it. Below is the output of the terraform plan

The terraform.tfstate file was created in the directory. Then i ran the command “terrafom apply TestTf”. This will eventually create the pc resource in the AWS account

This also shows that the vpc was created in the AWS account 

I added a new resource block to create the AWS subnets resource that will be tied to the vpc resource. In the code, I referenced the vpc_id that I created earlier and used a CIDR block of “10.0.1.0/24” . This subnet is a public one and this  depends on the vpc.. I also created the public  one with a CIDR block of “10.0.0.0/24” .After adding this code, i ran the terraform plan as well as the terraform apply for the new changes. Below is the code as well as the terraform apply output


resource "aws_subnet" "dev-subnet-public-1" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true" #This makes the subnet public
  availability_zone       = "us-east-1a"
  depends_on              = [aws_vpc.dev-vpc]

  tags = {
    Name = "dev-public-subnet"
  }
}
resource "aws_subnet" "dev-subnet-private-1" {
  vpc_id                  = aws_vpc.dev-vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = "true" #This makes the subnet public
  availability_zone       = "us-east-1c"
  depends_on              = [aws_vpc.dev-vpc, aws_subnet.dev-subnet-public-1]

  tags = {
    Name = "dev-private-subnet"
  }
}



Here is a snip showing that the public and the private subnet was created in AWS account

Next is the internet gateway, which enables the transfer of communication between your network and the internet. Still in the same main.tf file, I added the following code below. Also, i ran the terraform plan and apply.

resource "aws_internet_gateway" "dev-igw" { #This enables your vpc to connect to the internet
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    Name = "dev-internet-gateway"
  }
}

The next line of code is added to the main.tf file is the route table which create a route that points to the internet 


# Create a Custom Route Table
resource "aws_route_table" "dev-public-crt" {
  vpc_id = aws_vpc.dev-vpc.id
  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //Custom Route Table uses this Internet Gateway to reach internet
    gateway_id = aws_internet_gateway.dev-igw.id
  }

  tags = {
    Name = "dev-Route-Table"
  }
}

# Associate Custom Route Table and Subnet
resource "aws_route_table_association" "dev-crta-public-subnet-1" {
  subnet_id      = aws_subnet.dev-subnet-public-1.id
  route_table_id = aws_route_table.dev-public-crt.id
}

The following were created in order to provision  the EC2 resource in the VPC created:

First, I created the resource block for the security group. A security group  acts as a virtual firewall for your EC2 instances to control incoming and outgoing traffic. After you associate a security group  with an EC2 instance, it controls the inbound and outbound traffic for the instance. I provided the ingress and egress rule for the group. I also referenced the vpc id as the security group depends on it. Then i ran the terraform plan and terraform apply in my command terminal. Below is a snip of the security group in thee AWS account

resource "aws_security_group" "dev-ssh-allowed" {
  vpc_id = aws_vpc.dev-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    // This means, all ip address are allowed to ssh ! 
    // Do not do it in the production. 
    // Put your office or home address in it!
    cidr_blocks = ["0.0.0.0/0"]
  }
  //If you do not add this rule, you can not reach the NGIX  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "dev-ssh-allowed"
  }
}

Go to the AWS console, and search EC2. Scroll down the EC2 dashboard and select AMI catalog.

Scroll down the AMI Catalog and copy the AMI id for the service you want to use. For me, I made use of the Ubuntu Server 22.04 LTS (HVM), SSD Volume Type with ami id: ami-0574da719dca65348. Copy the AMI Id and create variables.tf file where you would be adding the value for your AMI id.

I also ran the command  in the terminal to create the key pair for the EC2 resource. This automatically creates two files in the directory: public and private keys :

                       ssh-keygen -f vpc-key-pair

I added the variables for the private and public key as this was utilized when creating the EC2 resource

I created the resource block  for the EC2 instance, I am using an ubuntu server. Alongside running the terraform plan and apply 

resource "aws_instance" "ubuntu-ec2" {
  ami           = var.AMI
  instance_type = "t2.micro"

  # VPC
  subnet_id = aws_subnet.dev-subnet-public-1.id

  #Security Groupdev-ssh-allowed
  vpc_security_group_ids = ["${aws_security_group.dev-ssh-allowed.id}"]

  # the Public SSH Key
  key_name  = aws_key_pair.vpc-key_pair.id
  user_data = file("${path.root}/userdata.sh")

 
  connection {
    user        = var.EC2_USER
    private_key = file("${var.PRIVATE_KEY_PATH}")
  }
}
