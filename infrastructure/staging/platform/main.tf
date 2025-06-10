terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-backends193093"
    key    = "staging/platform"
    region = "us-east-1"
  }
  required_version = "~> 1.12.0"
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "staging-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_ipv6                                   = true
  public_subnet_assign_ipv6_address_on_creation = true

  public_subnet_ipv6_prefixes  = [0, 1, 2]
  private_subnet_ipv6_prefixes = [3, 4, 5]

}

resource "aws_default_security_group" "default" {
  vpc_id = module.vpc.vpc_id
  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

module "s3_bucket_lambdas_389239" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  bucket                   = "lambdas-389239"
  force_destroy            = true
  request_payer            = "BucketOwner"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  restrict_public_buckets  = true
}


module "s3_bucket_nfts_38029" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  bucket                   = "nfts-38029"
  force_destroy            = false
  request_payer            = "BucketOwner"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  restrict_public_buckets  = true
  versioning = {
    enabled = true
  }
}
module "s3_bucket_frontend-380220" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  bucket                   = "frontend-380220"
  force_destroy            = false
  request_payer            = "BucketOwner"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  restrict_public_buckets  = true
  versioning = {
    enabled = true
  }
}


resource "aws_ecr_repository" "generate-nft" {
  name                 = "generate-nft"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

