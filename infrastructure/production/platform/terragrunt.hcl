include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../modules/platform"
}

inputs = {
  nfts_storage_bucket_name = "nfts-38029"
  trust_store_bucket_name  = "trust-store-38220"
  frontend_bucket_name     = "staging.nftbyai.shop"
  snapshot_identifier      = ""
}
