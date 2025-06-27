
variable "environment_name" {
  type    = string
}

variable "account_id" {
  type    = string
  default = "111111111111"
}

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "auth0_domain" {
  description = "Auth0 tenant domain"
  type        = string
  default     = "https://dev-4zljthbwh3wy24vx.us.auth0.com"
}

variable "auth0_issuer" {
  description = "Auth0 issuer URL"
  type        = string
  default     = "https://dev-4zljthbwh3wy24vx.us.auth0.com/"
}

variable "auth0_api_audience" {
  description = "Identifier of the API registered in Auth0"
  type        = string
  default     = "https://staging.nftbyai.shop/api"
}

variable "auth0_algorithms" {
  description = "JWT signing algorithm used by Auth0"
  type        = string
  default     = "RS256"
}

variable "ALLOW_ORIGINS_URLS" {
  description = "Public URL of the front-end SPA"
  type        = list(string)
  default     = ["http://staging.nftbyai.shop", "https://staging.nftbyai.shop", "http://staging-api.nftbyai.shop", "https://staging-api.nftbyai.shop"]
}

variable "FRONTEND_URL" {
  type    = string
  default = "http://staging.nftbyai.shop"
}

variable "SUCCESSFULL_PURCHASE_URL" {
  type    = string
  default = "http://staging.nftbyai.shop/confirmation"
}

variable "default_nft_owner" {
  description = "Default NFT owner identifier (scheme:user:chain)"
  type        = string
  default     = "email:owner@example.com:polygon"
}

variable "nft_image_storage_url" {
  description = "Base URL where NFT images are stored"
  type        = string
  default     = "https://nfts-38029.s3.us-east-1.amazonaws.com"
}

variable "elastic_load_balancer_certificate_arn" {
  type    = string
  default = "arn:aws:acm:us-east-1:111111111111:certificate/01cec85c-1454-47a2-995f-f50db290a47f"
}


variable "db_instance_address" {
  type = string
}

variable "db_instance_port" {
  type = string
}
variable "db_instance_name" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "db_instance_resource_id" {
  type = string
}

variable "nfts_s3_bucket_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "db_instance_sg" {

}

variable "GPT_MODEL_1" {
}
