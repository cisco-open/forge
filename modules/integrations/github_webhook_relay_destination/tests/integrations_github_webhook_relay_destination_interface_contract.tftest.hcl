run "integrations_github_webhook_relay_destination_interface_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_interface_contract"
  }

  variables {
    module_path = "."
    expected_input_variables = [
      "aws_profile",
      "aws_region",
      "default_tags",
      "reader_config",
      "tags",
      "webhook_relay_destination_config",
    ]
    expected_output_values = [
      "role_arn",
      "webhook",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "type        = string",
      "description = \"AWS profile to use.\"",
      "variable \"aws_region\"",
      "description = \"AWS region to use.\"",
      "variable \"default_tags\"",
      "type = map(string)",
      "variable \"reader_config\"",
      "description = \"Configuration for IAM role creation and secret retrieval\"",
      "type = object({",
      "role_name              = string",
      "role_trust_principals  = list(string)",
      "source_secret_role_arn = string",
      "enable_secret_fetch    = bool",
      "source_secret_arn      = string",
      "source_secret_region   = string",
      "default = {",
      "role_name              = \"github-webhook-relay-secret-reader\"",
      "role_trust_principals  = []",
      "source_secret_role_arn = \"\"",
      "enable_secret_fetch    = false",
      "source_secret_arn      = \"\"",
      "source_secret_region   = \"\"",
      "variable \"tags\"",
      "type    = map(string)",
      "default = {}",
      "variable \"webhook_relay_destination_config\"",
      "description = \"All configuration for the destination EventBridge relay\"",
      "name_prefix                = string",
      "destination_event_bus_name = string",
      "source_account_id          = string",
      "targets = list(object({",
      "event_pattern       = string",
      "lambda_function_arn = string",
      "}))",
      "name_prefix                = \"webhook-relay-destination\"",
      "destination_event_bus_name = \"webhook-relay-destination\"",
      "source_account_id          = \"\"",
      "targets                    = []",
      "output \"role_arn\"",
      "value       = aws_iam_role.reader.arn",
      "description = \"Local role ARN.\"",
      "output \"webhook\"",
      "value       = try(data.external.fetch_secret_value[0].result.secret_value, null)",
      "sensitive   = true",
      "description = \"Webhook relay and secret fetched from source account.\"",
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
      output.expected_input_variable_count == 6
      && output.expected_output_value_count == 2
      && output.expected_interface_literal_count == 46
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
