variable "detector_notifications" {
  description = "Detector notification destinations."
  type        = list(string)
}

variable "detector_name_prefix" {
  description = "Prefix to use for Splunk Observability detector names."
  type        = string
}

variable "dynamic_variables" {
  description = "Additional dynamic variable definitions used to derive detector scope."
  type = list(object({
    property               = string
    alias                  = string
    description            = string
    values                 = list(string)
    value_required         = bool
    values_suggested       = list(string)
    restricted_suggestions = bool
  }))
  default = []
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
}

variable "k8s_platform_namespaces" {
  description = "Namespaces that contain platform pods required for runner scheduling and networking."
  type        = list(string)
}

variable "team" {
  description = "Team ID."
  type        = string
}

variable "tenant_names" {
  description = "List of Forge tenant namespaces."
  type        = list(string)
}
