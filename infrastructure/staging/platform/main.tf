terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.5.0"
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

  enable_ipv6                                   = false
  public_subnet_assign_ipv6_address_on_creation = false
  intra_subnet_assign_ipv6_address_on_creation  = false
  private_subnet_enable_dns64                   = false

  # public_subnet_ipv6_prefixes  = [0, 1, 2]
  # private_subnet_ipv6_prefixes = [3, 4, 5]

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
    # ipv6_cidr_blocks = ["::/0"]
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
  restrict_public_buckets  = false
  block_public_policy      = false
  versioning = {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "s3_bucket_nfts_38029" {
  bucket                  = module.s3_bucket_nfts_38029.s3_bucket_id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "s3_bucket_nfts_38029_policy" {
  bucket = module.s3_bucket_nfts_38029.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudflareRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${module.s3_bucket_nfts_38029.s3_bucket_arn}/*"
        # Condition = {
        #   IpAddress = {
        #     "aws:SourceIp" = local.cf_source_cidrs # for now without cloudflare, later we may adjust so that images are only accessible through cloudflare
        #   }
        # }
      }
    ]
  })
}



module "s3_bucket_staging_nftbyai_shop" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  bucket                   = "staging.nftbyai.shop"
  force_destroy            = false
  request_payer            = "BucketOwner"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  restrict_public_buckets  = false
  block_public_policy      = false
  versioning = {
    enabled = true
  }
}
resource "aws_s3_bucket_website_configuration" "website_hosting" {
  bucket = module.s3_bucket_staging_nftbyai_shop.s3_bucket_id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}
resource "aws_s3_bucket_public_access_block" "example" {
  bucket                  = module.s3_bucket_staging_nftbyai_shop.s3_bucket_id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


data "cloudflare_ip_ranges" "cf" {}

locals {
  cf_source_cidrs = concat(
    data.cloudflare_ip_ranges.cf.ipv4_cidrs,
    data.cloudflare_ip_ranges.cf.ipv6_cidrs
  )
}

resource "aws_s3_bucket_policy" "restrict_to_cloudflare" {
  bucket     = module.s3_bucket_staging_nftbyai_shop.s3_bucket_id
  depends_on = [aws_s3_bucket_public_access_block.example]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudflareRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${module.s3_bucket_staging_nftbyai_shop.s3_bucket_arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = local.cf_source_cidrs
          }
        }
      }
    ]
  })
}


module "trust_store_38220" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  bucket                   = "trust-store-38220"
  force_destroy            = false
  request_payer            = "BucketOwner"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  restrict_public_buckets  = true
  versioning = {
    enabled = true
  }
}
resource "aws_s3_bucket_policy" "allow_alb_access" {
  bucket = module.trust_store_38220.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBTrustStoreRead"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.trust_store_38220.s3_bucket_arn}/rootca.crt"
      }
    ]
  })
}



resource "aws_lb_trust_store" "trust_store" {
  name                             = "lb-trust-store"
  ca_certificates_bundle_s3_bucket = module.trust_store_38220.s3_bucket_id
  ca_certificates_bundle_s3_key    = "rootca.crt"
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

