variable "aws_budget" {
  description = "Defines the budget and billing limits for AWS accounts and services."
  type = object(
    {
      per_account = string
      services = map(
        object(
          {
            budget_limit = string
          }
        )
      )
    }
  )
}

variable "aws_account_id" {
  description = "AWS account ID associated with the infra/backend."
  type        = string
}

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
