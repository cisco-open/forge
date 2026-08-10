variable "region" {
  type        = string
  description = "AWS region where the reconciler and Splunk Data Manager stacks run."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to reconciler resources."
}
