locals {
  env            = basename(get_terragrunt_dir())        # e.g. “prod” or “stage”   
  aws_region     = "us-east-1"
  account_id = get_aws_account_id()
  s3_bucket_name     = "terraform-state-${local.env}-${local.account_id}"
}

remote_state {
  backend = "s3"
  config = {
    bucket         = local.s3_bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    use_lockfile = true
  }
}