variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "splunk_otel_collector" {
  description = "Configuration for the Splunk OpenTelemetry Collector"
  type = object({
    splunk_observability_realm     = string
    splunk_platform_endpoint       = string
    splunk_platform_index          = string
    gateway                        = bool
    splunk_observability_profiling = bool
    environment                    = string
    discovery                      = bool
  })
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}
