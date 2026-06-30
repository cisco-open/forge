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
  description = "A map of default tags to apply to resources."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for created AWS resources."
  default     = "forge-stuck-workflow-job-dispatcher"
}

variable "logging_retention_in_days" {
  type        = number
  description = "Number of days to retain Lambda and API logs."
  default     = 14
}

variable "log_level" {
  type        = string
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)."
  default     = "INFO"
}

variable "splunk_conf" {
  type = object({
    splunk_cloud = string
    acl = object({
      app     = string
      owner   = string
      sharing = string
      read    = list(string)
      write   = list(string)
    })
    index        = string
    tenant_names = optional(list(string), [])
  })
  description = <<-EOT
    Splunk Cloud connection, ACL, and Forge index settings.

    Nested attributes:
    - splunk_cloud: Splunk Cloud host name used by the Splunk provider.
    - acl: Access control settings for the saved search.
    - acl.app: Splunk app that owns the saved search.
    - acl.owner: Splunk owner for the saved search.
    - acl.sharing: Splunk sharing scope for the saved search ACL.
    - acl.read: Splunk roles allowed to read the saved search.
    - acl.write: Splunk roles allowed to update the saved search.
    - index: Splunk index containing Forge CICD webhook and dispatch logs.
    - tenant_names: Optional tenant allow-list retained for compatibility with shared Splunk configuration.
  EOT
}

variable "redelivery_config" {
  type = object({
    tenant_configs = optional(list(object({
      tenant             = string
      github_api_version = optional(string)
      gh_config = object({
        ghes_url = string
      })
      prefixes = list(object({
        aws_region        = string
        deployment_prefix = string
      }))
    })), [])
  })
  description = <<-EOT
    GitHub App webhook redelivery behavior.

    Nested attributes:
    - tenant_configs: Tenant-specific GitHub Enterprise and deployment prefix mappings.
    - tenant_configs.tenant: Forge tenant name from Splunk logs.
    - tenant_configs.github_api_version: Optional GitHub API version header; defaults to 2022-11-28.
    - tenant_configs.gh_config: GitHub deployment settings for the tenant.
    - tenant_configs.gh_config.ghes_url: GitHub Enterprise Server base URL; empty string selects github.com.
    - tenant_configs.prefixes: AWS region-specific deployment prefix mappings for the tenant.
    - tenant_configs.prefixes.aws_region: AWS region where the tenant GitHub App SSM parameters are stored.
    - tenant_configs.prefixes.deployment_prefix: SSM prefix under /forge/<deployment_prefix>/ for GitHub App credentials.
  EOT
  default     = {}
}

variable "splunk_alert" {
  type = object({
    name                    = optional(string, "Forge stuck workflow_job dispatcher")
    description             = optional(string, "Queues GitHub App webhook redelivery when Forge workflow_job queued events stay stuck after dispatch.")
    disabled                = optional(bool, false)
    cron_schedule           = optional(string, "*/1 * * * *")
    dispatch_earliest_time  = optional(string, "-24h")
    dispatch_latest_time    = optional(string, "now")
    stuck_minutes_threshold = optional(number, 5)
    suppress_period         = optional(string, "30m")
  })
  description = <<-EOT
    Splunk saved-search alert configuration.

    Nested attributes:
    - name: Splunk saved-search name.
    - description: Splunk saved-search description.
    - disabled: Whether to create the saved search in a disabled state.
    - cron_schedule: Cron schedule for evaluating the saved search.
    - dispatch_earliest_time: Earliest Splunk search time for each alert run.
    - dispatch_latest_time: Latest Splunk search time for each alert run.
    - stuck_minutes_threshold: Minimum queued duration before redelivery is triggered.
    - suppress_period: Splunk alert suppression window for duplicate stuck-job results.
  EOT
  default     = {}
}

variable "dedupe_ttl_seconds" {
  type        = number
  description = "Seconds to suppress duplicate redelivery work for the same workflow job."
  default     = 1800
}
