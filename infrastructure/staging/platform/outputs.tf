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
  value = module.s3_bucket_nfts_38029.s3_bucket_id
}




# vpc
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_arn" {
  value = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "vpc_ipv6_cidr_block" {
  value = module.vpc.vpc_ipv6_cidr_block
}

output "azs" {
  value = module.vpc.azs
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "private_subnet_arns" {
  value = module.vpc.private_subnet_arns
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "public_subnet_arns" {
  value = module.vpc.public_subnet_arns
}

output "default_security_group_id" {
  value = module.vpc.default_security_group_id
}

output "default_network_acl_id" {
  value = module.vpc.default_network_acl_id
}

output "default_route_table_id" {
  value = module.vpc.default_route_table_id
}
