include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/db_configuration"
}


dependency "platform"{
  config_path = "../platform"
}

inputs = {
db_instance_name = dependency.platform.outputs.db_instance_name  
db_instance_username = dependency.platform.outputs.db_instance_username
}






