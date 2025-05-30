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

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "nftdb"

  engine         = "postgres"
  engine_version = "17.2"
  instance_class = "db.t4g.micro"
  family         = "postgres17"

  db_name                             = "nftdb"
  username                            = "root"
  port                                = "5432"
  iam_database_authentication_enabled = true

  storage_type       = "gp3"
  allocated_storage  = 20
  storage_encrypted  = true
  maintenance_window = "Mon:01:00-Mon:02:00"
  backup_window      = "03:00-03:30"

  backup_retention_period = 7
  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  availability_zone      = "us-east-1a"
  create_db_subnet_group = true
  subnet_ids             = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
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
}
