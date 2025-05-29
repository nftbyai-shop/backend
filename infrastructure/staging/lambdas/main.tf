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

module "lambda_rds_user_setup" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "produce_nft"
  description   = "Function that produces nft and stores it in rds"
  handler       = "produce_nft.lambda_handler"
  runtime       = "python3.12"
  publish       = true

  source_path = "lambdas/produce_nft.py"

  store_on_s3 = true
  s3_bucket   = "lambdas-389239"

  environment_variables = {
    DB_USER              = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_username
    DB_HOST              = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address
    DB_NAME              = "nftdb"
    DB_PASS_ARN          = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_master_user_secret_arn
    MIGRATION_USERNAME   = "MIGRATION_USER"
    APPLICATION_USERNAME = "APPLICATION_USER"
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
        "Sid" : "AllowLogs",
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        "Resource" : "*"
      }
    ]
  })
}

