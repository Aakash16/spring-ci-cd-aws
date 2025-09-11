variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-west-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "dynamodb_table_name" {
  type    = string
  default = "demo-table"
}

# keep bucket name fixed as requested
variable "s3_bucket_name" {
  type    = string
  default = "springboot-cicd-test-bucket-11092025"
}

variable "sqs_name" {
  type    = string
  default = "demo-queue"
}

variable "kms_alias_name" {
  type    = string
  default = "alias/test-key"
}