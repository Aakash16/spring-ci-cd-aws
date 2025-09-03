variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-west-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}