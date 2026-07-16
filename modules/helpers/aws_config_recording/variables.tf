variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  description = "Default AWS region."
  type        = string
}

variable "default_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}

variable "tags" {
  description = "A map of additional tags to apply to resources."
  type        = map(string)
}

variable "delivery_bucket_name" {
  description = "Name of the existing S3 bucket that receives AWS Config data. The bucket can be in another Region or account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.delivery_bucket_name))
    error_message = "The delivery bucket name must be a valid 3-63 character S3 bucket name."
  }
}

variable "recorded_resource_types" {
  description = "AWS Config resource types to record, using identifiers such as AWS::EC2::Instance."
  type        = set(string)

  validation {
    condition     = length(var.recorded_resource_types) > 0
    error_message = "At least one AWS Config resource type must be provided."
  }
}

variable "iam_role_name" {
  description = "Name of the IAM role used by AWS Config. Defaults to forge-aws-config-recorder-<aws_region>."
  type        = string
  default     = null
}

variable "recorder_name" {
  description = "Name of the AWS Config configuration recorder."
  type        = string
  default     = "default"
}

variable "delivery_channel_name" {
  description = "Name of the AWS Config delivery channel."
  type        = string
  default     = "default"
}
