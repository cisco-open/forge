run "integrations_splunk_stuck_workflow_job_dispatcher_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "dedupe_ttl_seconds",
      "default_tags",
      "log_level",
      "logging_retention_in_days",
      "name_prefix",
      "redelivery_config",
      "splunk_alert",
      "splunk_conf",
      "tags",
    ]
    expected_output_values = [
      "api_endpoint",
      "api_log_group_name",
      "dedupe_table_name",
      "receiver_lambda_function_arn",
      "receiver_lambda_log_group_name",
      "saved_search_name",
      "splunk_webhook_url",
      "worker_lambda_function_arn",
      "worker_lambda_log_group_name",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"dedupe_ttl_seconds\"",
      "type        = number",
      "description = \"Seconds to suppress duplicate redelivery work for the same workflow job.\"",
      "default     = 1800",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of default tags to apply to resources.\"",
      "variable \"log_level\"",
      "description = \"Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR).\"",
      "default     = \"INFO\"",
      "variable \"logging_retention_in_days\"",
      "description = \"Number of days to retain Lambda and API logs.\"",
      "default     = 14",
      "variable \"name_prefix\"",
      "description = \"Prefix for created AWS resources.\"",
      "default     = \"forge-stuck-workflow-job-dispatcher\"",
      "variable \"redelivery_config\"",
      "type = object({",
      "tenant_configs = optional(list(object({",
      "tenant             = string",
      "github_api_version = optional(string)",
      "gh_config = object({",
      "ghes_url = string",
      "prefixes = list(object({",
      "aws_region        = string",
      "deployment_prefix = string",
      "}))",
      "})), [])",
      "description = <<-EOT",
      "GitHub App webhook redelivery behavior.",
      "Nested attributes:",
      "- tenant_configs: Tenant-specific GitHub Enterprise and deployment prefix mappings.",
      "- tenant_configs.tenant: Forge tenant name from Splunk logs.",
      "- tenant_configs.github_api_version: Optional GitHub API version header; defaults to 2022-11-28.",
      "- tenant_configs.gh_config: GitHub deployment settings for the tenant.",
      "- tenant_configs.gh_config.ghes_url: GitHub Enterprise Server base URL; empty string selects github.com.",
      "- tenant_configs.prefixes: AWS region-specific deployment prefix mappings for the tenant.",
      "- tenant_configs.prefixes.aws_region: AWS region where the tenant GitHub App SSM parameters are stored.",
      "- tenant_configs.prefixes.deployment_prefix: SSM prefix under /forge/<deployment_prefix>/ for GitHub App credentials.",
      "EOT",
      "default     = {}",
      "variable \"splunk_alert\"",
      "name                    = optional(string, \"Forge stuck workflow_job dispatcher\")",
      "description             = optional(string, \"Queues GitHub App webhook redelivery when Forge workflow_job queued events stay stuck after dispatch.\")",
      "disabled                = optional(bool, false)",
      "cron_schedule           = optional(string, \"*/1 * * * *\")",
      "dispatch_earliest_time  = optional(string, \"-24h\")",
      "dispatch_latest_time    = optional(string, \"now\")",
      "stuck_minutes_threshold = optional(number, 5)",
      "suppress_period         = optional(string, \"30m\")",
      "Splunk saved-search alert configuration.",
      "- name: Splunk saved-search name.",
      "- description: Splunk saved-search description.",
      "- disabled: Whether to create the saved search in a disabled state.",
      "- cron_schedule: Cron schedule for evaluating the saved search.",
      "- dispatch_earliest_time: Earliest Splunk search time for each alert run.",
      "- dispatch_latest_time: Latest Splunk search time for each alert run.",
      "- stuck_minutes_threshold: Minimum queued duration before redelivery is triggered.",
      "- suppress_period: Splunk alert suppression window for duplicate stuck-job results.",
      "variable \"splunk_conf\"",
      "splunk_cloud = string",
      "acl = object({",
      "app     = string",
      "owner   = string",
      "sharing = string",
      "read    = list(string)",
      "write   = list(string)",
      "index        = string",
      "tenant_names = optional(list(string), [])",
      "Splunk Cloud connection, ACL, and Forge index settings.",
      "- splunk_cloud: Splunk Cloud host name used by the Splunk provider.",
      "- acl: Access control settings for the saved search.",
      "- acl.app: Splunk app that owns the saved search.",
      "- acl.owner: Splunk owner for the saved search.",
      "- acl.sharing: Splunk sharing scope for the saved search ACL.",
      "- acl.read: Splunk roles allowed to read the saved search.",
      "- acl.write: Splunk roles allowed to update the saved search.",
      "- index: Splunk index containing Forge CICD webhook and dispatch logs.",
      "- tenant_names: Optional tenant allow-list retained for compatibility with shared Splunk configuration.",
      "variable \"tags\"",
      "description = \"A map of tags to apply to resources.\"",
      "output \"api_endpoint\"",
      "description = \"Base HTTP API endpoint for the Splunk alert webhook receiver.\"",
      "value       = aws_apigatewayv2_api.splunk.api_endpoint",
      "output \"api_log_group_name\"",
      "description = \"CloudWatch log group containing API Gateway HTTP API access logs.\"",
      "value       = aws_cloudwatch_log_group.api.name",
      "output \"dedupe_table_name\"",
      "description = \"DynamoDB table used to suppress duplicate dispatches.\"",
      "value       = aws_dynamodb_table.dedupe.name",
      "output \"receiver_lambda_function_arn\"",
      "description = \"Splunk webhook receiver Lambda ARN.\"",
      "value       = module.dispatcher.lambda_function_arn",
      "output \"receiver_lambda_log_group_name\"",
      "description = \"CloudWatch log group containing Splunk webhook receiver Lambda logs.\"",
      "value       = aws_cloudwatch_log_group.dispatcher.name",
      "output \"saved_search_name\"",
      "description = \"Splunk saved search alert name.\"",
      "value       = var.splunk_alert.name",
      "output \"splunk_webhook_url\"",
      "description = \"Full Splunk webhook URL, including the shared path token.\"",
      "value       = local.splunk_webhook_url",
      "sensitive   = true",
      "output \"worker_lambda_function_arn\"",
      "description = \"GitHub App redelivery worker Lambda ARN.\"",
      "value       = module.worker.lambda_function_arn",
      "output \"worker_lambda_log_group_name\"",
      "description = \"CloudWatch log group containing GitHub App redelivery worker Lambda logs.\"",
      "value       = aws_cloudwatch_log_group.worker.name",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0
    error_message = "Interface contract is missing input variables: ${join(", ", output.missing_input_variables)}"
  }

  assert {
    condition     = length(output.unexpected_input_variables) == 0
    error_message = "Interface contract has unexpected input variables: ${join(", ", output.unexpected_input_variables)}"
  }

  assert {
    condition     = length(output.missing_output_values) == 0
    error_message = "Interface contract is missing outputs: ${join(", ", output.missing_output_values)}"
  }

  assert {
    condition     = length(output.unexpected_output_values) == 0
    error_message = "Interface contract has unexpected outputs: ${join(", ", output.unexpected_output_values)}"
  }

  assert {
    condition     = length(output.missing_interface_literals) == 0
    error_message = "Interface contract is missing expected variable/output source lines: ${join(", ", output.missing_interface_literals)}"
  }

  assert {
    condition = (
      output.expected_input_variable_count == 11
      && output.expected_output_value_count == 9
      && output.expected_interface_literal_count == 114
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
