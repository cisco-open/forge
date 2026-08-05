run "integrations_github_webhook_relay_destination_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "output \"role_arn\"",
      "output \"webhook\"",
      "provider \"aws\"",
      "resource \"aws_cloudwatch_event_bus\" \"destination\"",
      "resource \"aws_cloudwatch_event_bus_policy\" \"allow_source\"",
      "resource \"aws_cloudwatch_event_rule\" \"receive\"",
      "resource \"aws_cloudwatch_event_target\" \"lambda\"",
      "resource \"aws_lambda_permission\" \"eventbridge_invoke\"",
      "data \"aws_iam_policy_document\" \"trust\"",
      "resource \"aws_iam_role\" \"reader\"",
      "data \"aws_iam_policy_document\" \"allow_assume_external\"",
      "resource \"aws_iam_role_policy\" \"allow_assume_external_inline\"",
      "data \"external\" \"fetch_secret_value\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 13
    error_message = "Source inventory must keep 13 module-specific Terraform blocks pinned."
  }
}
