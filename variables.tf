variable "region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}


variable "securityhub_enable" {
  description = "Enable Security Hub in the account"
  type        = bool
  default     = true
}
