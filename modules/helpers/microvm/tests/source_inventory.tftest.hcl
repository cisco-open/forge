run "helpers_microvm_source_inventory" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"aws_s3_bucket\" \"artifacts\"",
      "resource \"aws_s3_bucket_ownership_controls\" \"artifacts\"",
      "resource \"aws_s3_bucket_versioning\" \"artifacts\"",
      "resource \"aws_s3_bucket_server_side_encryption_configuration\" \"artifacts\"",
      "resource \"aws_s3_bucket_public_access_block\" \"artifacts\"",
      "resource \"aws_s3_bucket_lifecycle_configuration\" \"artifacts\"",
      "resource \"aws_s3_bucket_policy\" \"artifacts\"",
      "resource \"aws_iam_role\" \"build\"",
      "resource \"aws_iam_policy\" \"build\"",
      "resource \"aws_iam_policy\" \"usage\"",
      "resource \"aws_iam_role_policy_attachment\" \"build\"",
      "resource \"aws_cloudformation_stack\" \"connector\"",
      "Type = \"AWS::Lambda::NetworkConnector\"",
      "VpcEgressConfiguration",
      "AssociatedComputeResourceTypes = [\"MicroVm\"]",
      "Value       = { Ref = \"Connector\" }",
      "Value       = { \"Fn::GetAtt\" = [\"Connector\", \"State\"] }",
      "resource \"aws_security_group\" \"connector\"",
      "resource \"aws_vpc_security_group_egress_rule\" \"ipv4\"",
      "resource \"aws_vpc_security_group_egress_rule\" \"ipv6\"",
      "cidr_ipv4         = \"0.0.0.0/0\"",
      "cidr_ipv6         = \"::/0\"",
      "resource \"aws_iam_role\" \"operator\"",
      "resource \"aws_iam_role_policy_attachment\" \"operator\"",
      "AWSLambdaNetworkConnectorOperatorPolicy",
      "OperatorRole = aws_iam_role.operator.arn",
      "for_each = var.network_connectors",
      "resource \"aws_servicecatalogappregistry_application\" \"this\"",
      "provider \"aws\"",
      "\"lambda:RunMicrovm\"",
      "\"lambda:TerminateMicrovm\"",
      "\"s3:GetObject\"",
      "\"ecr:GetAuthorizationToken\"",
      "\"ecr:BatchGetImage\"",
      "\"logs:CreateLogGroup\"",
      "\"logs:CreateLogStream\"",
      "\"logs:PutLogEvents\"",
      "resources = [local.image_arn_pattern]",
      "\"lambda:GetNetworkConnector\"",
      "\"lambda:ListNetworkConnectors\"",
      "\"lambda:PassNetworkConnector\"",
      "resources = values(local.connector_arns)",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks or least-privilege IAM actions: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 42
    error_message = "Source inventory must keep 42 MicroVM build, runtime, connector, and IAM boundary literals pinned."
  }

}
