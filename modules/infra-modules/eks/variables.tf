variable "aws_account_id" {
  description = "AWS account ID associated with the infra/backend."
  type        = string
}

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

variable "cluster_version" {
  description = "The version of the EKS cluster"
  type        = string
}

variable "cluster_size" {
  description = "The size config of the EKS cluster"
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  })
}

variable "subnet_ids" {
  description = "A list of private subnet IDs for worker nodes"
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "cluster_tags" {
  type        = map(string)
  description = "Cluster tags"
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
