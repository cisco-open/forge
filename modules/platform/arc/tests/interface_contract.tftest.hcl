run "platform_arc_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "controller_config",
      "eks_cluster_name",
      "ghes_org",
      "ghes_url",
      "github_app",
      "log_level",
      "migrate_arc_cluster",
      "multi_runner_config",
      "runner_group_name",
      "tags",
    ]
    expected_output_values = [
      "runners_map",
      "subnet_cidr_blocks",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"Assuming single region for now.\"",
      "variable \"controller_config\"",
      "type = object({",
      "release_name  = string",
      "namespace     = string",
      "chart_name    = string",
      "chart_version = string",
      "name          = string",
      "description = <<EOT",
      "controller_config = {",
      "release_name: \"Name of the Helm release.\"",
      "namespace: \"Namespace for chart installation.\"",
      "chart_name: \"Chart name for the Helm chart.\"",
      "chart_version: \"Chart version for the Helm chart.\"",
      "name: \"Name of the controller.\"",
      "EOT",
      "variable \"eks_cluster_name\"",
      "description = \"Name of the EKS cluster\"",
      "variable \"ghes_org\"",
      "description = \"GitHub organization.\"",
      "variable \"ghes_url\"",
      "description = \"GitHub Enterprise Server URL.\"",
      "variable \"github_app\"",
      "description = \"GitHub App configuration\"",
      "key_base64      = string",
      "id              = string",
      "installation_id = string",
      "variable \"log_level\"",
      "description = \"Log level for ARC controller and runner pod commands (e.g., INFO, DEBUG, WARN, ERROR). When set to DEBUG, runner template shell commands and dockerd run in verbose mode.\"",
      "default     = \"INFO\"",
      "variable \"migrate_arc_cluster\"",
      "type        = bool",
      "description = \"Flag to indicate if the cluster should be migrated.\"",
      "default     = false",
      "variable \"multi_runner_config\"",
      "type = map(object({",
      "runner_set_configs = object({",
      "runner_config = object({",
      "runner_size = object({",
      "max_runners = number",
      "min_runners = number",
      "prefix                       = string",
      "scale_set_name               = string",
      "scale_set_type               = string",
      "scale_set_labels             = list(string)",
      "container_limits_cpu         = string",
      "container_limits_memory      = string",
      "container_requests_cpu       = string",
      "container_requests_memory    = string",
      "volume_requests_storage_size = string",
      "volume_requests_storage_type = string",
      "container_images = optional(object({",
      "actions_runner = optional(string, \"ghcr.io/actions/actions-runner:latest\")",
      "busybox        = optional(string, \"public.ecr.aws/docker/library/busybox:stable\")",
      "dind_rootless  = optional(string, \"public.ecr.aws/docker/library/docker:dind-rootless\")",
      "}), {})",
      "container_ecr_registries            = list(string)",
      "runner_iam_role_managed_policy_arns = list(string)",
      "controller = object({",
      "service_account = string",
      "namespace       = string",
      "}))",
      "multi_runner_config = {",
      "runner_config: {",
      "runner_size: {",
      "max_runners: \"Maximum number of runners.\"",
      "min_runners: \"Minimum number of runners.\"",
      "controller = {",
      "service_account: \"Service Account Name of the controller.\"",
      "namespace: \"Namespace for the controller.\"",
      "prefix: \"Prefix for naming resources.\"",
      "scale_set_name: \"Name of the scale set.\"",
      "scale_set_labels: \"GitHub runner labels advertised by the ARC scale set.\"",
      "container_images: \"Container images used by the ARC runner, sidecars, and DinD containers.\"",
      "runner_iam_role_managed_policy_arns: \"Attach AWS or customer-managed IAM policies (by ARN) to the runner IAM role.\"",
      "runner_set_configs: {",
      "variable \"runner_group_name\"",
      "description = \"Name of the group applied to all runners.\"",
      "variable \"tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "output \"runners_map\"",
      "value = { for key, value in module.scale_sets : key => value }",
      "output \"subnet_cidr_blocks\"",
      "value = length(var.multi_runner_config) < 1 ? {} : { for id, subnet in data.aws_subnet.eks_subnets : id => subnet.cidr_block }",
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
      output.expected_input_variable_count == 12
      && output.expected_output_value_count == 2
      && output.expected_interface_literal_count == 89
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
