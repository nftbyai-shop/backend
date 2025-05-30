output "private_subnets" {
  value = module.vpc.private_subnets
}
output "public_subnets" {
  value = module.vpc.public_subnets
}
output "db_instance_username" {
  value = module.db.db_instance_username
}
output "db_instance_address" {
  value = module.db.db_instance_address
}
output "db_instance_master_user_secret_arn" {
  value = module.db.db_instance_master_user_secret_arn
}
output "db_instance_resource_id" {
  value = module.db.db_instance_resource_id
}

output "s3_bucket_name_for_nfts" {
  value = module.s3_bucket_lambdas_389239.s3_bucket_id
}
