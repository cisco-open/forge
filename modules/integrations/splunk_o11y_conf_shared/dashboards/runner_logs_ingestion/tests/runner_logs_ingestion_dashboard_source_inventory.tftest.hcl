run "runner_logs_ingestion_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"runner_logs_ingestion\"",
      "Forge Runner Logs Ingestion",
      "Runner-log Lambda duration guardrail",
      "Runner-log oldest message age - 6h trend",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "terraform_data.dashboard_parent,",
      "not filter('aws_tag_TenantName', '*')",
      "filter('QueueName', 'splunk-s3-runner-logs-events')",
      "filter('QueueName', 'splunk-s3-runner-logs-events-dlq')",
      "filter('aws_function_name', 'splunk-s3-runner-logs-lambda-*')",
      "filter('StreamName', 'splunk-s3-runner-logs-stream-*')",
      "filter('DeliveryStreamName', 'splunk-s3-runner-logs-firehose-*')",
      "filter('namespace', 'AWS/Firehose')",
      "__forge_aws_account_scope_not_configured__",
      "__forge_aws_region_scope_not_configured__",
      "__forge_product_family_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Runner-log ingestion dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }
}
