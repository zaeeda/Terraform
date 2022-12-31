provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "dev-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" #This will be used to give the vpc internal domain name
  enable_dns_hostnames = "true" #This will be used to give the vpc internal host name
  #instance_tenancy     = default #If you put this as true, your ec2 will be he only physical hardwar in AWS

  tags = {
    Name = "dev-vpc"
  }
}

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

# Create an Internet gateway
resource "aws_internet_gateway" "dev-igw" { #This enables your vpc to connect to the internet
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    Name = "dev-internet-gateway"
  }
}


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

#Create the Security Group for the Ec2: Secutiyr acts as a virtual firewall for your EC2 instances to control incoming and outgoing traffic
#After you associate a security group  with an EC2 instance, it controls the inbound and outbound traffic for the instance
#Create the Security Group
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

  #nginix installation
  #provisioner "file" {
  #  source      = "nginix.sh"
  #  destination = "/tmp/nginix.sh"
  #}
  #
  #provisioner "remote-exec" {
  #  inline = [
  #    "chmof + x /tmp/nginix.sh",
  #    "sudo /tmp/nginx.sh"
  #  ]

  #}
  connection {
    user        = var.EC2_USER
    private_key = file("${var.PRIVATE_KEY_PATH}")
  }
}

# Create and assosiate an Elastic IP
resource "aws_eip" "eip" {
  instance = aws_instance.ubuntu-ec2.id
}

resource "aws_key_pair" "vpc-key_pair" {
  key_name   = "vpc-key-pair"
  public_key = file("${var.PUBLIC_KEY_PATH}")

}