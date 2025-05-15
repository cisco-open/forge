variable "chart_name" {
  description = "Chart URL for the Helm chart"
  type        = string
}

variable "chart_version" {
  description = "Chart version for the Helm chart"
  type        = string
}

variable "namespace" {
  description = "Namespace for chart installation"
  type        = string
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
}

variable "controller_config" {
  type = object({
    name = string
  })
}

variable "github_app" {
  description = "GitHub App configuration"
  type = object({
    key_base64      = string
    id              = string
    installation_id = string
  })
}
