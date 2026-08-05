variable "vpc_id" {

}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks permitted to reach the bastion on port 22. Supplied per-operator via the BASTION_SSH_CIDR environment variable — never commit a real address."
  type        = list(string)
}
variable "subnet_id" {

}
variable "default_security_group_id" {

}

