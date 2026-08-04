terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.0.0"
    }
  }
  required_version = "~> 1.12.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-ssh-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id
  ingress {
    description = "SSH from anywhere (not recommended for production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["198.51.100.7/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id, var.default_security_group_id]
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
