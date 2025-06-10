terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-backends193093"
    key    = "bastion-host"
    region = "us-east-1"
  }
  required_version = "~> 1.12.0"
}

provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "platform_deployment_state" {
  backend = "s3"
  config = {
    bucket = "terraform-backends193093"
    key    = "staging/platform"
    region = "us-east-1"
  }
}


# 1. Security group allowing SSH
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-ssh-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  ingress {
    description = "SSH from anywhere (not recommended for production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["198.51.100.7/32"] # Restrict in production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# # 2. EC2 Key Pair (you can also import an existing key)
# resource "aws_key_pair" "bastion_key" {
#   key_name   = "bastion-key"
#   public_key = file("~/.ssh/id_rsa.pub")
# }

# 3. Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id, data.terraform_remote_state.platform_deployment_state.outputs.default_security_group_id]
  key_name                    = "MyKeyPair"
  associate_public_ip_address = true
  tags = {
    Name = "BastionHost"
  }
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP of the bastion host"
}
