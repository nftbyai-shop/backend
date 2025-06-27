terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.0.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.25"
    }
  }
  required_version = "~> 1.12.0"
}

data "aws_ssm_parameter" "db_password" {
  name            = "db_password"
  with_decryption = true
}

data "terraform_remote_state" "platform_deployment_state" {
  backend = "s3"
  config = {
    bucket = "terraform-backends193093"
    key    = "staging/platform"
    region = "us-east-1"
  }
}

provider "postgresql" {
  host      = "localhost"
  port      = 15432
  username  = var.db_instance_username
  password  = data.aws_ssm_parameter.db_password.value
  database  = "postgres"
  sslmode   = "require"
  superuser = false
}

locals {
  app_user = "app_user"
}

resource "postgresql_role" "app_user" {
  name  = local.app_user
  login = true
  roles = ["rds_iam"]
}

resource "postgresql_grant" "app_user_connect" {
  depends_on  = [postgresql_role.app_user]
  database    = var.db_instance_name
  role        = local.app_user
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_default_privileges" "app_user_tables" {
  depends_on  = [postgresql_role.app_user]
  role        = local.app_user
  owner       = var.db_instance_username
  database    = var.db_instance_name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE"]
}

resource "postgresql_default_privileges" "app_user_sequences" {
  depends_on  = [postgresql_role.app_user]
  owner       = var.db_instance_username
  role        = local.app_user
  database    = var.db_instance_name
  schema      = "public"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}
