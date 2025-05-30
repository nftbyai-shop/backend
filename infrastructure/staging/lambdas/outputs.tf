

output "rds_user_setup_lambda_name" {
  value = module.lambda_for_adding_rds_users.lambda_function_name
}

output "generate_nft_lambda_name" {
  value = module.generate_nft.lambda_function_name
}

output "generate_nft_lambda_arn" {
  value = module.lambda_for_generating_nft.lambda_function_arn
}
output "rds_user_setup_lambda_arn" {
  value = module.lambda_for_adding_rds_users.lambda_function_arn
}
