include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/platform"
}

inputs = {
  nfts_storage_bucket_name = "nfts-${get_aws_account_id()}"
  trust_store_bucket_name  = "trust-store-${get_aws_account_id()}"
  frontend_bucket_name     = "staging.nftbyai.shop"
  snapshot_identifier      = "final-nftdb-e350698a"
}
