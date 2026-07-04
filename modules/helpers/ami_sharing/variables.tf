variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  description = "Assuming single region for now."
  type        = string
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "account_ids" {
  description = "List of AWS accounts to share AMIs with"
  type        = list(string)
}

variable "ami_name_filters" {
  description = "AMI name filter to use to find AMIs to share"
  type        = list(string)
}
