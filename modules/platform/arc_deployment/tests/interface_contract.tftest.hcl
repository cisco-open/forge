run "platform_arc_deployment_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "runner_configs",
      "tenant_configs",
    ]
    expected_output_values = [
      "arc_cluster_name",
      "arc_runners_arn_map",
      "arc_runners_labels_map",
      "subnet_cidr_blocks",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Assuming single region for now.\"",
      "variable \"runner_configs\"",
      "type = object({",
      "prefix           = string",
      "arc_cluster_name = string",
      "ghes_url         = string",
      "ghes_org         = string",
      "github_app = object({",
      "key_base64      = string",
      "id              = string",
      "installation_id = string",
      "migrate_arc_cluster                 = optional(bool, false)",
      "runner_iam_role_managed_policy_arns = list(string)",
      "runner_group_name                   = string",
      "log_level                           = optional(string, \"INFO\")",
      "runner_specs = map(object({",
      "runner_size = object({",
      "max_runners = number",
      "min_runners = number",
      "scale_set_name   = string",
      "scale_set_type   = string",
      "scale_set_labels = list(string)",
      "container_images = optional(object({",
      "actions_runner = optional(string, \"ghcr.io/actions/actions-runner:latest\")",
      "busybox        = optional(string, \"public.ecr.aws/docker/library/busybox:stable\")",
      "dind_rootless  = optional(string, \"public.ecr.aws/docker/library/docker:dind-rootless\")",
      "}), {})",
      "container_limits_cpu         = string",
      "container_limits_memory      = string",
      "volume_requests_storage_size = string",
      "volume_requests_storage_type = string",
      "container_requests_cpu       = string",
      "container_requests_memory    = string",
      "}))",
      "variable \"tenant_configs\"",
      "ecr_registries = list(string)",
      "tags           = map(string)",
      "name           = string",
      "output \"arc_cluster_name\"",
      "value       = var.runner_configs.arc_cluster_name",
      "description = \"Name of the Kubernetes cluster used for ARC runners.\"",
      "output \"arc_runners_arn_map\"",
      "value = {",
      "for runner_key, runner in module.arc.runners_map : runner_key => runner.runner_role_arn",
      "description = \"Map of ARC runner keys to their IAM role ARNs.\"",
      "output \"arc_runners_labels_map\"",
      "runner_key => spec.scale_set_labels",
      "description = \"Map of ARC runner keys to their GitHub scale set labels.\"",
      "output \"subnet_cidr_blocks\"",
      "value       = module.arc.subnet_cidr_blocks",
      "description = \"Map of ARC runner subnet IDs to their CIDR blocks.\"",
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
      && output.expected_output_value_count == 4
      && output.expected_interface_literal_count == 55
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
