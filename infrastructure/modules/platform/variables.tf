variable "nfts_storage_bucket_name" {
  type    = string
  default = "nfts-38029"
}

variable "trust_store_bucket_name" {
  type    = string
  default = "trust-store-38220"
}

variable "frontend_bucket_name" {
  type    = string
  default = "staging.nftbyai.shop"
}

variable "snapshot_identifier" {
  type    = string
  default = ""
}
