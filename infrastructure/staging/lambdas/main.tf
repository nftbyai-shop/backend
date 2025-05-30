terraform {
  backend "s3" {
    bucket       = "terraform-backends193093"
    key          = "lambda-deploy"
    region       = "us-east-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  required_version = ">= 1.2.0"
}

data "terraform_remote_state" "platform_deployment_state" {
  backend = "s3"
  config = {
    bucket = "terraform-backends193093"
    key    = "staging/platform"
    region = "us-east-1"
  }
}

locals {
  application_username                  = "APPLICATION_USER"
  migration-script-service-rds-username = "MIGRATION_USER"
}

module "lambda_for_adding_rds_users" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "setup_rds_users"
  description   = "lambda that sets up rds users and their permissions"
  handler       = "setup_rds_users.lambda_handler"
  runtime       = "python3.12"
  publish       = true

  source_path = "../../../lambdas/setup_rds_users"


  store_on_s3 = true
  s3_bucket   = "lambdas-389239"

  environment_variables = {
    DB_USER              = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_username
    DB_HOST              = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address
    DB_NAME              = "nftdb"
    DB_PASS_ARN          = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_master_user_secret_arn
    MIGRATION_USERNAME   = local.migration-script-service-rds-username
    APPLICATION_USERNAME = local.application_username
  }
  vpc_subnet_ids     = data.terraform_remote_state.platform_deployment_state.outputs.private_subnets
  attach_policy_json = true

  policy_json = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowSecretsManagerRead",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "arn:aws:secretsmanager:us-east-1:111111111111:secret:rds*"
      },
      {
        "Sid" : "AdminAccess",
        "Effect" : "Allow",
        "Action" : "*",
        "Resource" : "*"
      }
    ]
  })
}

module "lambda_for_generating_nft" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "generate_nft"
  description   = "lambda that generates nft and stores in rds"
  handler       = "produce_nft.lambda_handler"
  runtime       = "python3.12"
  publish       = true

  source_path = {
    path             = "../../../lambdas/produce_nft"
    pip_requirements = "requirements.txt"
    commands = [
      ":zip . ."
    ]
  }

  store_on_s3 = true
  s3_bucket   = "lambdas-389239"

  environment_variables = {
    DB_USER                    = local.application_username
    DB_HOST                    = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address
    DB_NAME                    = "nftdb"
    DB_PASS_ARN                = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_master_user_secret_arn
    MIGRATION_USERNAME         = "MIGRATION_USER"
    APPLICATION_USERNAME       = "APPLICATION_USER"
    CROSSMINT_API_KEY_SSM_PATH = "/staging/nft-producer-service/CROSSMINT_API_KEY"
    OPENAI_API_KEY_SSM_PATH    = "/staging/nft-producer-service/OPENAI_API_KEY"
    COLLECTION_ID              = "2f36274e-3463-49c1-9ee4-a01205674540"
    GPT_MODEL_1                = "gpt-4.1-nano"
    IMAGE_GEN_MODEL            = "dall-e-2"
    NFT_RECIPIENT              = "email:owner@example.com:polygon"
    S3_BUCKET                  = data.terraform_remote_state.platform_deployment_state.outputs.s3_bucket_name_for_nfts
    LOG_LEVEL                  = "DEBUG"
    IMAGE_SIZE                 = "1024x1024"
    IMAGE_QUALITY              = "standard"
  }
  vpc_subnet_ids     = data.terraform_remote_state.platform_deployment_state.outputs.private_subnets
  attach_policy_json = true

  policy_json = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AdminAccess",
        "Effect" : "Allow",
        "Action" : "*"
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : "rds-db:connect",
        "Resource" : "arn:aws:rds-db:us-east-1:111111111111:db-user:${data.terraform_remote_state.platform_deployment_state.outputs.db_instance_resource_id}/${local.application_username}"
      }
    ]
  })
}

