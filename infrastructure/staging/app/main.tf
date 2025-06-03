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
# probably delete
# data "terraform_remote_state" "lambdas" {
#   backend = "s3"
#   config = {
#     bucket = "terraform-backends193093"
#     key    = "lambda-deploy"
#     region = "us-east-1"
#   }
# }

# resource "aws_scheduler_schedule" "example" {
#   name       = "my-schedule"
#   group_name = "default"
#   flexible_time_window { mode = "OFF" }
#   schedule_expression = "rate(1 hours)"
#   target {
#     arn      = data.terraform_remote_state.lambdas.outputs.generate_nft_lambda_arn
#     role_arn = aws_iam_role.scheduler_lambda.arn 
#   }
# }

# resource "aws_iam_role" "scheduler_lambda" {
#   name = "scheduler-lambda-exec"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect    = "Allow",
#       Principal = { Service = "scheduler.amazonaws.com" },
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
#   name = "scheduler-lambda-invoke"
#   role = aws_iam_role.scheduler_lambda.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect   = "Allow",
#       Action   = ["lambda:InvokeFunction"],
#       Resource = data.terraform_remote_state.lambdas.outputs.
#       #Resource = aws_lambda_function.my_function.arn
#     }]
#   })
# }

locals {
  application_username = "app_user"
}

module "lambda_for_generating_nft" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "generate_nft"
  description   = "lambda that generates nft and stores in rds"
  handler       = "produce_nft.lambda_handler"
  runtime       = "python3.12"
  publish       = true
  timeout       = 900
  source_path = {
    path = "../../../lambdas/produce_nft"
    # pip_requirements = true,
    commands = [
      "cd ../../../lambdas/produce_nft",
      "pip3 install -r requirements.txt -t .",
      ":zip . ."
    ]
  }
  store_on_s3 = true
  s3_bucket   = "lambdas-389239"
  environment_variables = {
    DB_USER                    = local.application_username
    DB_HOST                    = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address
    DB_NAME                    = "nftdb"
    REGION                     = "us-east-1"
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
  layers = ["arn:aws:lambda:us-east-1:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension:17"]

  vpc_security_group_ids      = [data.terraform_remote_state.platform_deployment_state.outputs.default_security_group_id]
  vpc_subnet_ids              = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets[1]
  ipv6_allowed_for_dual_stack = true
  attach_network_policy       = true

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

