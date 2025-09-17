variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
}

variable "environment_variables" {
  type        = map(string)
  description = "A map of environment variables to set for the Lambda function."
}

variable "region" {
  type        = string
  description = "The AWS region to deploy resources."
}
