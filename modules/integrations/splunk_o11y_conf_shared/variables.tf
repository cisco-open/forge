variable "aws_profile" {
  type        = string
  description = "AWS profile (i.e., generated via 'sl aws session generate') to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "splunk_api_url" {
  description = "URL for plunk Observability Cloud API."
  type        = string
}

variable "splunk_organization_id" {
  description = "organization ID for Splunk Observability Cloud."
  type        = string
}

variable "team" {
  description = "Team ID"
  type        = string
}

variable "dashboard_variables" {
  type = object({
    runner_k8s = object({
      tenant_names = list(string)
      dynamic_variables = list(object({
        property               = string
        alias                  = string
        description            = string
        values                 = list(string)
        value_required         = bool
        values_suggested       = list(string)
        restricted_suggestions = bool
        }
      ))
    })
    runner_ec2 = object({
      tenant_names = list(string)
      dynamic_variables = list(object({
        property               = string
        alias                  = string
        description            = string
        values                 = list(string)
        value_required         = bool
        values_suggested       = list(string)
        restricted_suggestions = bool
        }
      ))
    })
    billing = object({
      tenant_names = list(string)
      dynamic_variables = list(object({
        property               = string
        alias                  = string
        description            = string
        values                 = list(string)
        value_required         = bool
        values_suggested       = list(string)
        restricted_suggestions = bool
        }
      ))
    })
    sqs_performance = object({
      tenant_names = list(string)
      dynamic_variables = list(object({
        property               = string
        alias                  = string
        description            = string
        values                 = list(string)
        value_required         = bool
        values_suggested       = list(string)
        restricted_suggestions = bool
        }
      ))
    })
  })
  description = "Variables for Dashboards"
}
