run "platform_forge_runners_forge_trust_validator_contract" {
  command = plan

  module {
    source = "../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "module \"forge_trust_preparer_lambda\"",
      "module \"forge_trust_validator_lambda\"",
      "resource \"aws_iam_role_policy\" \"forge_trust_preparer_lambda\"",
      "resource \"aws_iam_role_policy\" \"forge_trust_validator_lambda\"",
      "resource \"aws_sqs_queue\" \"forge_trust_validator\"",
      "resource \"aws_cloudwatch_log_group\" \"forge_trust_preparer_lambda\"",
      "resource \"aws_cloudwatch_log_group\" \"forge_trust_validator_lambda\"",
      "resource \"aws_cloudwatch_event_rule\" \"forge_trust_preparer_lambda\"",
      "resource \"aws_cloudwatch_event_target\" \"forge_trust_preparer_lambda\"",
      "resource \"aws_lambda_event_source_mapping\" \"forge_trust_validator_lambda\"",
      "resource \"aws_lambda_permission\" \"forge_trust_preparer_lambda\"",
      "data \"aws_partition\" \"current\"",
      "data \"aws_caller_identity\" \"current\"",
      "data \"aws_iam_policy_document\" \"forge_trust_preparer_lambda\"",
      "data \"aws_iam_policy_document\" \"forge_trust_validator_lambda\"",
    ]
    forbidden_literals = [
      "Principal = \"*\"",
      "resources = [\"*\"]",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Module contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Module contract must pin at least one module-specific literal."
  }

  assert {
    condition     = length(output.present_forbidden_literals) == 0
    error_message = "Module contract includes forbidden literals: ${join(", ", output.present_forbidden_literals)}"
  }
}
