run "platform_ec2_deployment_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_region",
      "network_configs",
      "runner_configs",
      "tenant_configs",
    ]
    expected_output_values = [
      "ec2_runners_ami_name_map",
      "ec2_runners_arn_map",
      "ec2_runners_labels_map",
      "event_bus_name",
      "subnet_cidr_blocks",
      "webhook_endpoint",
    ]
    expected_interface_literals = [
      "variable \"aws_region\"",
      "type        = string",
      "description = \"Assuming single region for now.\"",
      "variable \"network_configs\"",
      "type = object({",
      "vpc_id            = string",
      "subnet_ids        = list(string)",
      "lambda_vpc_id     = string",
      "lambda_subnet_ids = list(string)",
      "variable \"runner_configs\"",
      "env                       = string",
      "prefix                    = string",
      "ghes_url                  = string",
      "ghes_org                  = string",
      "log_level                 = string",
      "logging_retention_in_days = string",
      "github_app = object({",
      "key_base64     = string",
      "id             = string",
      "webhook_secret = string",
      "runner_iam_role_managed_policy_arns = list(string)",
      "runner_group_name                   = string",
      "scale_errors                        = optional(list(string), [])",
      "runner_specs = map(object({",
      "ami_filter = object({",
      "name  = list(string)",
      "state = list(string)",
      "ami_kms_key_arn                                                = string",
      "ami_owners                                                     = list(string)",
      "runner_labels                                                  = list(string)",
      "runner_os                                                      = string",
      "runner_architecture                                            = string",
      "extra_labels                                                   = list(string)",
      "enable_dynamic_labels                                          = optional(bool, false)",
      "ec2_dynamic_labels_policy                                      = optional(any, null)",
      "lambda_event_source_mapping_batch_size                         = optional(number, 10)",
      "lambda_event_source_mapping_maximum_batching_window_in_seconds = optional(number, 0)",
      "max_instances                                                  = number",
      "min_run_time                                                   = number",
      "instance_types                                                 = list(string)",
      "license_specifications = optional(list(object({",
      "license_configuration_arn = string",
      "})), null)",
      "placement = optional(object({",
      "affinity                = optional(string)",
      "availability_zone       = optional(string)",
      "group_id                = optional(string)",
      "group_name              = optional(string)",
      "host_id                 = optional(string)",
      "host_resource_group_arn = optional(string)",
      "spread_domain           = optional(string)",
      "tenancy                 = optional(string)",
      "partition_number        = optional(number)",
      "}), null)",
      "use_dedicated_host = optional(bool, false)",
      "pool_config = list(object({",
      "size                         = number",
      "schedule_expression          = string",
      "schedule_expression_timezone = string",
      "}))",
      "runner_user                   = string",
      "enable_userdata               = bool",
      "instance_target_capacity_type = string",
      "vpc_id                        = optional(string, null)",
      "subnet_ids                    = optional(list(string), null)",
      "block_device_mappings = list(object({",
      "delete_on_termination = bool",
      "device_name           = string",
      "encrypted             = bool",
      "iops                  = number",
      "kms_key_id            = string",
      "snapshot_id           = string",
      "throughput            = number",
      "volume_size           = number",
      "volume_type           = string",
      "variable \"tenant_configs\"",
      "ecr_registries = list(string)",
      "tags           = map(string)",
      "lambda_event_source_mapping_batch_size                         = val[\"lambda_event_source_mapping_batch_size\"]",
      "lambda_event_source_mapping_maximum_batching_window_in_seconds = val[\"lambda_event_source_mapping_maximum_batching_window_in_seconds\"]",
      "output \"ec2_runners_ami_name_map\"",
      "value = {",
      "for runner_key, runner in module.runners.runners_map : runner_key => data.aws_ami.runner_ami[runner_key].name",
      "description = \"Map of EC2 runner keys to the AMI names used for each runner.\"",
      "output \"ec2_runners_arn_map\"",
      "for runner_key, runner in module.runners.runners_map : runner_key => runner.role_runner[0].arn",
      "description = \"Map of EC2 runner keys to their IAM role ARNs.\"",
      "output \"ec2_runners_labels_map\"",
      "runner_key => concat(spec.runner_labels, spec.extra_labels)",
      "description = \"Map of EC2 runner keys to their base and extra GitHub labels.\"",
      "output \"event_bus_name\"",
      "value       = module.runners.webhook.eventbridge.event_bus.name",
      "description = \"Name of the EventBridge event bus used by the webhook relay.\"",
      "output \"subnet_cidr_blocks\"",
      "value       = { for id, subnet in data.aws_subnet.runner_subnet : id => subnet.cidr_block }",
      "description = \"Map of EC2 runner subnet IDs to their CIDR blocks.\"",
      "output \"webhook_endpoint\"",
      "value       = module.runners.webhook.endpoint",
      "description = \"Public HTTPS endpoint URL for the GitHub Actions webhook relay.\"",
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
      output.expected_input_variable_count == 4
      && output.expected_output_value_count == 6
      && output.expected_interface_literal_count == 99
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
