include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/app"
}

dependency "platform"{
  config_path = "../platform"
}

locals {
  envs = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  env_envs = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  environment_name         = local.env_envs.locals.env_name
  account_id               = local.envs.locals.account_id
  region                   = local.envs.locals.aws_region

  auth0_custom_domain             = "https://staging-auth.nftbyai.shop"
  auth0_default_domain            = "https://dev-4zljthbwh3wy24vx.us.auth0.com"
  auth0_issuer             = "https://staging-auth.nftbyai.shop/"
  auth0_api_audience       = "https://staging.nftbyai.shop/api"
  auth0_algorithms         = ["RS256"]

  ALLOW_ORIGINS_URLS       = [
    "http://staging.nftbyai.shop",
    "https://staging.nftbyai.shop",
    "http://staging-api.nftbyai.shop",
    "https://staging-api.nftbyai.shop"
  ]

  FRONTEND_URL             = "http://staging.nftbyai.shop"
  SUCCESSFULL_PURCHASE_URL = "http://staging.nftbyai.shop/confirmation"
  FAILED_PURCHASE_URL       = "http://staging.nftbyai.shop"

  GPT_MODEL_1 = "gpt-4.1-mini"
  default_nft_owner                = get_env("NFT_OWNER_IDENTIFIER")
  smtp_user                        = get_env("SMTP_USER_EMAIL")
  report_to_email                  = get_env("REPORT_TO_EMAIL")
  nft_image_storage_url            = "https://nfts-${local.envs.locals.account_id}.s3.us-east-1.amazonaws.com"
  COLLECTION_ID                    = "2f36274e-3463-49c1-9ee4-a01205674540"
  elastic_load_balancer_certificate_arn = "arn:aws:acm:us-east-1:${local.envs.locals.account_id}:certificate/01cec85c-1454-47a2-995f-f50db290a47f"

  NFTBYAI_WALLET_ADDRESS ="0xA45BB78a84eA17CA64876D89CeD76ff1E837e759"
  PRICE_IN_CENTS = 500


  db_instance_address       = dependency.platform.outputs.db_instance_address
  db_instance_port          = dependency.platform.outputs.db_instance_port
  db_instance_name          = dependency.platform.outputs.db_instance_name
  public_subnet_ids         = dependency.platform.outputs.public_subnets
  db_instance_resource_id   = dependency.platform.outputs.db_instance_resource_id
  nfts_s3_bucket_name       = dependency.platform.outputs.s3_bucket_name_for_nfts
  vpc_id                    = dependency.platform.outputs.vpc_id
  db_instance_sg            = dependency.platform.outputs.db_instance_sg
}



