

##############################
# Authentication / Auth0
##############################
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

##############################
# Front-end / Client
##############################
variable "ALLOW_ORIGINS_URLS" {
  description = "Public URL of the front-end SPA"
  type        = list(string)
  default     = ["http://staging.nftbyai.shop", "https://staging.nftbyai.shop", "http://staging-api.nftbyai.shop", "https://staging-api.nftbyai.shop"]
}

variable "FRONTEND_URL" {
  type        = string
  default     = "http://staging.nftbyai.shop"
}


##############################
# NFT service
##############################
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

##############################
# General
##############################
variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}
