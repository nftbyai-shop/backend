include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/bastion_host"
}

dependency "platform"{
  config_path = "../platform"
}

inputs = {
  vpc_id =  dependency.platform.outputs.vpc_id
  subnet_id=  dependency.platform.outputs.public_subnets[0]
  default_security_group_id= dependency.platform.outputs.default_security_group_id
}
