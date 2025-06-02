
variable "COLLECTION_ID" {
  type        = string
  description = "ID of the NFT collection"
}

variable "GPT_MODEL_1" {
  type        = string
  description = "Name of the GPT model to use"
}

variable "IMAGE_GEN_MODEL" {
  type        = string
  description = "Image generation model"
}

variable "DB_USER" {
  type        = string
  description = "Database username"
}

variable "DB_PASS" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "DB_HOST" {
  type        = string
  description = "Database host"
}

variable "DB_NAME" {
  type        = string
  description = "Database name"
}

variable "NFT_RECIPIENT" {
  type        = string
  description = "Address to send NFTs to"
}

variable "S3_BUCKET" {
  type        = string
  description = "S3 bucket name"
}

variable "LOG_LEVEL" {
  type        = string
  description = "Application log level (e.g. info, debug)"
}


variable "OPENAI_API_KEY" {
  type = string
}

variable "CROSSMINT_API_KEY" {
  type = string
}


variable "IMAGE_SIZE" {
  type = string
}

variable "IMAGE_QUALITY" {
  type = string
}

