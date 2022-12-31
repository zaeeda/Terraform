variable "AWS_REGION" {
  default = "us-east-1"
}
variable "AMI" {
  default = "ami-0574da719dca65348"
}

variable "PUBLIC_KEY_PATH" {
  default = "vpc-key-pair.pub"
}

variable "PRIVATE_KEY_PATH" {
  default = "vpc-key-pair"
}

variable "EC2_USER" {
  default = "userforec2"
}