variable "name" {
  type        = string
  description = "Name that distinguishes this Splunk Data Manager configuration from others in the same region."
}

variable "region" {
  type        = string
  description = "AWS region where the reconciler and Splunk Data Manager stacks run."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to reconciler resources."
}
