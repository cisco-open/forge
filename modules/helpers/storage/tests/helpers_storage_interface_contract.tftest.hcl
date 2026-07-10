run "helpers_storage_interface_contract" {
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
      "tags",
    ]
    expected_output_values = [
      "s3_long_term_settings",
      "s3_short_term_settings",
    ]
    expected_interface_literals = [
      "variable \"aws_profile\"",
      "description = \"AWS profile to use.\"",
      "type        = string",
      "variable \"aws_region\"",
      "description = \"Default AWS region.\"",
      "variable \"default_tags\"",
      "type        = map(string)",
      "description = \"A map of tags to apply to resources.\"",
      "variable \"tags\"",
      "output \"s3_long_term_settings\"",
      "value = {",
      "\"path\"   = \"$${aws_s3_bucket.s3_long_term.id}/cicd_artifacts\"",
      "\"arn\"    = aws_s3_bucket.s3_long_term.arn",
      "\"suffix\" = \"/cicd_artifacts\"",
      "description = \"Path to use for long-term storage of artifacts in S3.\"",
      "output \"s3_short_term_settings\"",
      "\"path\"   = \"$${aws_s3_bucket.s3_short_term.id}/cicd_artifacts\"",
      "\"arn\"    = aws_s3_bucket.s3_short_term.arn",
      "description = \"Path to use for short-term storage of artifacts in S3.\"",
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
      && output.expected_output_value_count == 2
      && output.expected_interface_literal_count == 19
    )
    error_message = "Interface contract counts must remain pinned for inputs, outputs, and source literals."
  }
}
