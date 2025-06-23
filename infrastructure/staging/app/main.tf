terraform {
  backend "s3" {
    bucket       = "terraform-backends193093"
    key          = "app-deploy"
    region       = "us-east-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region                      = "us-east-1"
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
}

data "terraform_remote_state" "platform_deployment_state" {
  backend = "s3"
  config = {
    bucket = "terraform-backends193093"
    key    = "staging/platform"
    region = "us-east-1"
  }
}
