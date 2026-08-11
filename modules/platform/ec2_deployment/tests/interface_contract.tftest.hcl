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
      "ec2_runners_map",
      "event_bus_name",
      "microvm_runners_arn_map",
      "microvm_runners_labels_map",
      "microvm_runners_map",
      "runners_arn_map",
      "runners_labels_map",
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
      "runner_specs = map(object({",
      "runner_labels         = list(string)",
      "runner_os             = string",
      "runner_architecture   = string",
      "extra_labels          = list(string)",
      "enable_dynamic_labels = optional(bool, false)",
      "aws_dynamic_labels_policy = optional(object({",
      "blocked_keys = optional(list(string), [])",
      "restricted_keys = optional(map(object({",
      "allowed = optional(list(string), [])",
      "denied  = optional(list(string), [])",
      "max     = optional(string, null)",
      "lambda_event_source_mapping_batch_size                         = optional(number, 10)",
      "lambda_event_source_mapping_maximum_batching_window_in_seconds = optional(number, 0)",
      "redrive_build_queue = optional(object({",
      "enabled         = optional(bool, true)",
      "maxReceiveCount = optional(number, 10)",
      "max_instances = number",
      "min_run_time  = number",
      "pool_config = list(object({",
      "size                         = number",
      "schedule_expression          = string",
      "schedule_expression_timezone = string",
      "runner_user = string",
      "compute_provider = object({",
      "ec2 = optional(object({",
      "ami_filter = object({",
      "name  = list(string)",
      "state = list(string)",
      "ami_kms_key_arn = string",
      "ami_owners      = list(string)",
      "instance_types  = list(string)",
      "license_specifications = optional(list(object({",
      "license_configuration_arn = string",
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
      "use_dedicated_host            = optional(bool, false)",
      "enable_userdata               = bool",
      "instance_target_capacity_type = string",
      "vpc_id                        = optional(string, null)",
      "subnet_ids                    = optional(list(string), null)",
      "scale_errors                  = optional(list(string), [])",
      "block_device_mappings = list(object({",
      "delete_on_termination      = bool",
      "device_name                = string",
      "encrypted                  = bool",
      "iops                       = number",
      "kms_key_id                 = string",
      "snapshot_id                = string",
      "throughput                 = number",
      "volume_initialization_rate = optional(number)",
      "volume_size                = number",
      "volume_type                = string",
      "microvm = optional(object({",
      "image_identifier          = string",
      "image_version             = optional(string, null)",
      "egress_network_connectors = optional(list(string), [])",
      "idle_policy = optional(object({",
      "max_idle_duration_seconds  = number",
      "suspended_duration_seconds = number",
      "auto_resume_enabled        = bool",
      "logging = optional(object({",
      "cloud_watch = optional(object({",
      "log_group  = optional(string, null)",
      "log_stream = optional(string, null)",
      "disabled = optional(bool, false)",
      "run_hook_payload            = optional(string, null)",
      "maximum_duration_in_seconds = optional(number, null)",
      "environment_variables       = optional(map(string), {})",
      "tags                        = optional(map(string), {})",
      "iam = optional(object({",
      "resource_arns = optional(list(string), [\"*\"])",
      "scale_up   = optional(list(string), null)",
      "scale_down = optional(list(string), null)",
      "additional_policy_json = optional(object({",
      "managed_policy_arns = optional(object({",
      "pool     = optional(string, null)",
      "for runner_config in values(var.runner_configs.runner_specs) :",
      "if provider_config != null",
      "error_message = \"Each runner_specs entry must configure exactly one compute provider: ec2 or microvm.\"",
      "variable \"tenant_configs\"",
      "ecr_registries = list(string)",
      "tags           = map(string)",
      "if runner_config.compute_provider.ec2 != null",
      "if runner_config.compute_provider.microvm != null",
      "active_ec2_subnet_ids = toset(flatten([",
      "scale_errors                  = runner_config.compute_provider.ec2.scale_errors",
      "managed_policy_arns = merge(",
      "local.runner_iam_role_managed_policy_arns,",
      "forge_ec2_tags         = aws_iam_policy.ec2_tags[0].arn",
      "forge_runner_hooks_ssm = aws_iam_policy.runner_hooks_ssm_read[0].arn",
      "labelMatchers = length(runner_config.extra_labels) == 0 ? [runner_config.runner_labels] : concat(",
      "multi_runner_config = {}",
      "multi_runner_config_v2 = local.multi_runner_config_v2",
      "output \"runners_arn_map\"",
      "runner_key => module.runners.runners_map_v2[runner_key].provider.microvm.execution_role_arn",
      "output \"runners_labels_map\"",
      "value       = local.runner_labels",
      "output \"ec2_runners_map\"",
      "module.runners.runners_map_v2[runner_key].provider.ec2",
      "output \"ec2_runners_arn_map\"",
      "module.runners.runners_map_v2[runner_key].runner.role.arn",
      "output \"ec2_runners_ami_name_map\"",
      "data.aws_ami.runner_ami[runner_key].name",
      "output \"ec2_runners_labels_map\"",
      "output \"microvm_runners_map\"",
      "module.runners.runners_map_v2[runner_key].provider.microvm",
      "output \"microvm_runners_arn_map\"",
      "output \"microvm_runners_labels_map\"",
      "output \"event_bus_name\"",
      "value       = module.runners.webhook.eventbridge.event_bus.name",
      "output \"subnet_cidr_blocks\"",
      "value       = { for id, subnet in data.aws_subnet.runner_subnet : id => subnet.cidr_block }",
      "output \"webhook_endpoint\"",
      "value       = module.runners.webhook.endpoint",
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
      && output.expected_output_value_count == 12
      && output.expected_interface_literal_count == 145
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
