run "platform_arc_scale_set_interface_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "chart_name",
      "chart_version",
      "cluster_name",
      "container_ecr_registries",
      "container_images",
      "container_limits_cpu",
      "container_limits_memory",
      "container_requests_cpu",
      "container_requests_memory",
      "controller",
      "ghes_org",
      "ghes_url",
      "iam_role_name",
      "log_level",
      "migrate_arc_cluster",
      "namespace",
      "oidc_provider_arn",
      "release_name",
      "runner_group_name",
      "runner_iam_role_managed_policy_arns",
      "runner_size",
      "scale_set_labels",
      "scale_set_name",
      "scale_set_type",
      "secret_name",
      "service_account",
      "tags",
      "volume_requests_storage_size",
      "volume_requests_storage_type",
    ]
    expected_output_values = [
      "runner_role_arn",
    ]
    expected_interface_literals = [
      "variable \"chart_name\"",
      "description = \"Chart URL for the Helm chart\"",
      "type        = string",
      "variable \"chart_version\"",
      "description = \"Chart version for the Helm chart\"",
      "variable \"cluster_name\"",
      "description = \"Name of the EKS cluster.\"",
      "variable \"container_ecr_registries\"",
      "type        = list(string)",
      "description = \"List of ECR registries.\"",
      "variable \"container_images\"",
      "description = \"Container images used by the ARC runner, sidecars, and DinD containers.\"",
      "type = object({",
      "actions_runner = optional(string, \"ghcr.io/actions/actions-runner:latest\")",
      "busybox        = optional(string, \"public.ecr.aws/docker/library/busybox:stable\")",
      "dind_rootless  = optional(string, \"public.ecr.aws/docker/library/docker:dind-rootless\")",
      "default = {}",
      "variable \"container_limits_cpu\"",
      "description = \"Container CPU limits.\"",
      "variable \"container_limits_memory\"",
      "description = \"Container memory limits.\"",
      "variable \"container_requests_cpu\"",
      "description = \"Container CPU requests.\"",
      "variable \"container_requests_memory\"",
      "description = \"Container memory requests.\"",
      "variable \"controller\"",
      "namespace       = string",
      "service_account = string",
      "description = <<EOT",
      "controller = {",
      "namespace: \"Namespace for the controller.\"",
      "service_account: \"Service Account Name of the controller.\"",
      "EOT",
      "variable \"ghes_org\"",
      "description = \"GitHub organization.\"",
      "variable \"ghes_url\"",
      "description = \"GitHub Enterprise Server URL.\"",
      "variable \"iam_role_name\"",
      "description = \"The name of the Iam Role\"",
      "variable \"log_level\"",
      "description = \"Log level for runner pod commands (e.g., INFO, DEBUG, WARN, ERROR). When set to DEBUG, runner template shell commands and dockerd run in verbose mode.\"",
      "default     = \"INFO\"",
      "variable \"migrate_arc_cluster\"",
      "type        = bool",
      "description = \"Flag to indicate if the cluster is being migrated.\"",
      "default     = false",
      "variable \"namespace\"",
      "description = \"Namespace for chart installation\"",
      "variable \"oidc_provider_arn\"",
      "description = \"OIDC provider ARN for the EKS cluster.\"",
      "variable \"release_name\"",
      "description = \"Name of the Helm release\"",
      "variable \"runner_group_name\"",
      "description = \"Name of the group applied to all runners.\"",
      "variable \"runner_iam_role_managed_policy_arns\"",
      "description = \"Attach AWS or customer-managed IAM policies (by ARN) to the runner IAM role\"",
      "variable \"runner_size\"",
      "max_runners = number",
      "min_runners = number",
      "runner_size = {",
      "max_runners: \"Maximum number of runners.\"",
      "min_runners: \"Minimum number of runners.\"",
      "variable \"scale_set_labels\"",
      "description = \"GitHub runner labels advertised by the ARC scale set.\"",
      "variable \"scale_set_name\"",
      "description = \"Name of the scale set.\"",
      "variable \"scale_set_type\"",
      "description = \"Type of the scale set(k8s or dind).\"",
      "variable \"secret_name\"",
      "description = \"Name of the Secret.\"",
      "variable \"service_account\"",
      "description = \"Name of the Service Account.\"",
      "variable \"tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"volume_requests_storage_size\"",
      "description = \"Volume storage requests.\"",
      "variable \"volume_requests_storage_type\"",
      "output \"runner_role_arn\"",
      "value = aws_iam_role.runner_role.arn",
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
      output.expected_input_variable_count == 29
      && output.expected_output_value_count == 1
      && output.expected_interface_literal_count == 80
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
