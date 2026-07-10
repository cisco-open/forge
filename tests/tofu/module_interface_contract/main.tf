terraform {
  required_version = "~> 1.11"
}

variable "module_path" {
  type        = string
  description = "Filesystem path to the module under test."
  default     = "."
}

variable "expected_input_variables" {
  type        = list(string)
  description = "Input variables that make up the public module interface."
}

variable "expected_output_values" {
  type        = list(string)
  description = "Output values that make up the public module interface."
}

variable "expected_interface_literals" {
  type        = list(string)
  description = "Module-specific variable and output block lines that must remain present."
}

locals {
  tf_files = sort(fileset(var.module_path, "*.tf"))
  tf_text = join("\n", [
    for file_name in local.tf_files : file("${var.module_path}/${file_name}")
  ])

  declared_input_variables = sort(distinct([
    for match in regexall("(?m)^variable[[:space:]]+\"([^\"]+)\"", local.tf_text) : match[0]
  ]))

  declared_output_values = sort(distinct([
    for match in regexall("(?m)^output[[:space:]]+\"([^\"]+)\"", local.tf_text) : match[0]
  ]))

  missing_input_variables = sort(tolist(setsubtract(
    toset(var.expected_input_variables),
    toset(local.declared_input_variables),
  )))
  unexpected_input_variables = sort(tolist(setsubtract(
    toset(local.declared_input_variables),
    toset(var.expected_input_variables),
  )))

  missing_output_values = sort(tolist(setsubtract(
    toset(var.expected_output_values),
    toset(local.declared_output_values),
  )))
  unexpected_output_values = sort(tolist(setsubtract(
    toset(local.declared_output_values),
    toset(var.expected_output_values),
  )))

  missing_interface_literals = [
    for literal in var.expected_interface_literals : literal
    if !strcontains(local.tf_text, literal)
  ]
}

output "declared_input_variables" {
  value = local.declared_input_variables
}

output "declared_output_values" {
  value = local.declared_output_values
}

output "expected_input_variable_count" {
  value = length(var.expected_input_variables)
}

output "expected_output_value_count" {
  value = length(var.expected_output_values)
}

output "expected_interface_literal_count" {
  value = length(var.expected_interface_literals)
}

output "missing_input_variables" {
  value = local.missing_input_variables
}

output "unexpected_input_variables" {
  value = local.unexpected_input_variables
}

output "missing_output_values" {
  value = local.missing_output_values
}

output "unexpected_output_values" {
  value = local.unexpected_output_values
}

output "missing_interface_literals" {
  value = local.missing_interface_literals
}
