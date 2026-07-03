variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
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

variable "detector_notifications" {
  description = "Detector notification destinations. When null, detectors notify the configured Splunk Observability team. Set to [] to create detectors without notifications."
  type        = list(string)
  default     = null
}

variable "detector_name_prefix" {
  description = "Prefix to use for Splunk Observability detector names."
  type        = string
  default     = "ForgeCICD"
}

variable "dashboard_group_name" {
  description = "Name to use for the Splunk Observability dashboard group."
  type        = string
  default     = "ForgeCICD Dashboards"
}

variable "k8s_detector_config" {
  description = "Thresholds and durations for Forge Kubernetes detectors."
  type = object({
    container_restarts_duration  = string
    container_restarts_threshold = number
    failed_pods_duration         = string
    failed_pods_threshold        = number
    otel_no_data_duration        = string
    otel_no_data_fill_duration   = string
    pending_pods_duration        = string
    pending_pods_threshold       = number
    platform_pods_duration       = string
    platform_unhealthy_threshold = number
  })
  default = {
    container_restarts_duration  = "10m"
    container_restarts_threshold = 0
    failed_pods_duration         = "5m"
    failed_pods_threshold        = 0
    otel_no_data_duration        = "10m"
    otel_no_data_fill_duration   = "4h"
    pending_pods_duration        = "10m"
    pending_pods_threshold       = 0
    platform_pods_duration       = "5m"
    platform_unhealthy_threshold = 0
  }
}

variable "k8s_platform_namespaces" {
  description = "Namespaces that contain platform pods required for runner scheduling and networking."
  type        = list(string)
  default     = ["kube-system", "karpenter", "calico-system", "tigera-operator"]
}

variable "k8s_otel_collector_config" {
  description = "Configuration for Splunk OpenTelemetry Collector health detectors."
  type = object({
    min_running_pods       = number
    namespace              = string
    no_running_duration    = string
    pod_issue_duration     = string
    pod_name_filter        = string
    restart_duration       = string
    restart_threshold      = number
    stale_metrics_duration = string
  })
  default = {
    min_running_pods       = 1
    namespace              = "splunk-otel-collector"
    no_running_duration    = "10m"
    pod_issue_duration     = "5m"
    pod_name_filter        = "splunk-otel-collector*"
    restart_duration       = "10m"
    restart_threshold      = 0
    stale_metrics_duration = "4h"
  }
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
    sqs = object({
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
    ebs = object({
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
    lambda = object({
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
    dynamodb = object({
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
