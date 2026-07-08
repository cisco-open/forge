terraform {
  required_version = ">= 1.11.0"
}

variable "module_path" {
  type        = string
  description = "Filesystem path to the module under test."
  default     = "."
}

variable "expected_literals" {
  type        = list(string)
  description = "Module-specific Terraform source snippets that must remain present."
}

locals {
  tf_files = sort(fileset(var.module_path, "*.tf"))
  tf_text = join("\n", [
    for file_name in local.tf_files : file("${var.module_path}/${file_name}")
  ])

  missing_expected_literals = [
    for literal in var.expected_literals : literal
    if !strcontains(local.tf_text, literal)
  ]
}

output "expected_literal_count" {
  value = length(var.expected_literals)
}

output "missing_expected_literals" {
  value = local.missing_expected_literals
}
