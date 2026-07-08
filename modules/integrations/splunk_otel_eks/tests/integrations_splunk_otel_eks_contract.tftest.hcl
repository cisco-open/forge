run "integrations_splunk_otel_eks_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_iam_role\" \"splunk_otel_ec2_describe\"",
      "resource \"aws_iam_policy\" \"ec2_describe_instances\"",
      "resource \"aws_iam_role_policy_attachment\" \"splunk_otel_ec2_describe\"",
      "resource \"aws_eks_pod_identity_association\" \"eks_pod_identity\"",
      "resource \"time_sleep\" \"wait_for_pod_identity_propagation\"",
      "resource \"helm_release\" \"splunk_otel_collector\"",
      "data \"aws_eks_cluster\" \"cluster\"",
      "data \"aws_eks_cluster_auth\" \"cluster\"",
      "data \"aws_iam_openid_connect_provider\" \"cluster\"",
      "data \"aws_iam_policy_document\" \"splunk_otel_assume_role\"",
      "data \"aws_iam_policy_document\" \"ec2_describe_instances\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
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
}
