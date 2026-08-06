run "integrations_splunk_cloud_data_manager_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "cloudformation_s3_config",
      "cloudwatch_log_groups_config",
      "custom_cloudwatch_log_groups_config",
      "default_tags",
      "s3_logs_config",
      "security_metadata_config",
      "splunk_cloud",
      "tags",
    ]
    expected_output_values = [
      "splunk_cloud_input_cloudwatch_logs_json",
      "splunk_cloud_input_custom_logs_json",
      "splunk_cloud_input_s3_logs_json",
      "splunk_cloud_input_security_metadata_json",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "default     = \"us-east-1\"",
      "variable \"cloudformation_s3_config\"",
      "type = object({",
      "bucket = string",
      "key    = string",
      "region = string",
      "description = \"S3 bucket for CloudFormation templates.\"",
      "variable \"cloudwatch_log_groups_config\"",
      "enabled = bool",
      "name    = string",
      "datasource = object({",
      "cwl-api-gateway = optional(object({",
      "index   = string",
      "}))",
      "cwl-cloudhsm = optional(object({",
      "cwl-documentDB = optional(object({",
      "cwl-eks = optional(object({",
      "cwl-lambda = optional(object({",
      "cwl-rds = optional(object({",
      "cwl-vpc-flow-logs = optional(object({",
      "vpcIds  = any",
      "regions = list(string)",
      "description = \"Configuration for log groups including source type and name prefixes.\"",
      "default = {",
      "enabled    = false",
      "name       = \"\"",
      "datasource = {}",
      "regions    = []",
      "variable \"custom_cloudwatch_log_groups_config\"",
      "enabled     = bool",
      "name        = string",
      "index       = string",
      "source_type = string",
      "log_group_name_prefixes = list(object({",
      "region                = string",
      "log_group_name_prefix = string",
      "enabled                 = false",
      "name                    = \"\"",
      "index                   = \"\"",
      "source_type             = \"\"",
      "log_group_name_prefixes = []",
      "variable \"s3_logs_config\"",
      "s3-custom-logs = optional(list(object({",
      "ct-logs = optional(list(object({",
      "s3-access-logs = optional(list(object({",
      "elb-access-logs = optional(list(object({",
      "cf-access-logs = optional(list(object({",
      "enabled            = bool",
      "name               = string",
      "iam_region         = string",
      "index              = string",
      "source_type        = string",
      "sqs_urls           = list(string)",
      "s3_bucket_patterns = list(string)",
      "kms_key_arns       = list(string)",
      "description = \"Configuration for Splunk S3 log inputs grouped by dataset. Each enabled list item creates one Data Manager input.\"",
      "default     = {}",
      "nullable    = false",
      "validation {",
      "Every enabled s3-custom-logs input must provide source_type.",
      "Enabled S3 log input names must be unique across all datasets.",
      "Enabled S3 log inputs must use unique SQS queues.",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"security_metadata_config\"",
      "cloudtrail = optional(object({",
      "securityhub = optional(object({",
      "guardduty = optional(object({",
      "iam-aa = optional(object({",
      "iam-cr = optional(object({",
      "metadata = optional(object({",
      "variable \"splunk_cloud\"",
      "description = \"Splunk Cloud endpoint.\"",
      "variable \"tags\"",
      "output \"splunk_cloud_input_cloudwatch_logs_json\"",
      "description = \"The Splunk Cloud input map.\"",
      "value       = var.cloudwatch_log_groups_config.enabled ? local.splunk_cloud_input_cloudwatch_json : \"\"",
      "output \"splunk_cloud_input_custom_logs_json\"",
      "description = \"The Splunk Cloud input map for custom logs.\"",
      "value       = var.custom_cloudwatch_log_groups_config.enabled ? local.splunk_cloud_input_custom_logs_json : \"\"",
      "output \"splunk_cloud_input_s3_logs_json\"",
      "description = \"Map of enabled S3 log input names to their Splunk Cloud input JSON.\"",
      "value       = tomap(local.splunk_cloud_input_s3_logs_json)",
      "output \"splunk_cloud_input_security_metadata_json\"",
      "description = \"The Splunk Cloud input map for security metadata.\"",
      "value       = var.security_metadata_config.enabled ? local.splunk_cloud_input_security_metadata_json : \"\"",
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
      output.expected_input_variable_count == 10
      && output.expected_output_value_count == 4
      && output.expected_interface_literal_count == 92
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
