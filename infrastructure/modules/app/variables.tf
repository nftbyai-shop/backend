
variable "environment_name" {
  type = string
}

variable "account_id" {
  type = string
}

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "auth0_custom_domain" {
}
variable "auth0_default_domain" {
}

variable "auth0_issuer" {
  description = "Auth0 issuer URL"
  type        = string
}

variable "auth0_api_audience" {
  description = "Identifier of the API registered in Auth0"
  type        = string
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
variable "FAILED_PURCHASE_URL" {
}

variable "PRICE_IN_CENTS" {
}

variable "default_nft_owner" {
  description = "Identifier that holds newly minted NFTs until sale (scheme:user:chain)"
  type        = string
}

variable "smtp_user" {
  description = "Mailbox used as the envelope sender for operational mail"
  type        = string
}

variable "report_to_email" {
  description = "Destination for fulfillment failure alerts"
  type        = string
}
variable "NFTBYAI_WALLET_ADDRESS" {
}

variable "COLLECTION_ID" {
}

variable "nft_image_storage_url" {
  description = "Base URL where NFT images are stored"
  type        = string
  default     = "https://nfts-38029.s3.us-east-1.amazonaws.com"
}

variable "elastic_load_balancer_certificate_arn" {
  type = string
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
