run "metric_ingest_dashboard_interface_contract" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path              = "."
    expected_input_variables = ["dashboard_group", "token_ids"]
    expected_output_values   = []
    expected_interface_literals = [
      "variable \"dashboard_group\"",
      "variable \"token_ids\"",
      "description = \"Splunk Observability ingest token IDs owned by Forge. These are identifiers, not token secrets. An empty list makes every token-scoped chart fail closed.\"",
      "type        = list(string)",
      "length(distinct(var.token_ids)) == length(var.token_ids)",
      "for token_id in var.token_ids : can(regex(\"^[A-Za-z0-9_-]+$\", token_id))",
    ]
  }

  assert {
    condition     = length(output.missing_input_variables) == 0 && length(output.unexpected_input_variables) == 0
    error_message = "Metric-ingest dashboard input contract is not exact."
  }

  assert {
    condition     = length(output.missing_output_values) == 0 && length(output.unexpected_output_values) == 0
    error_message = "Metric-ingest dashboard must not expose unplanned outputs."
  }

  assert {
    condition     = length(output.missing_interface_literals) == 0
    error_message = "Metric-ingest dashboard variable validation contract is incomplete: ${join(", ", output.missing_interface_literals)}"
  }
}
