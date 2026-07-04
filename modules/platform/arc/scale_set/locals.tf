locals {
  github_config_url = var.ghes_url != "" ? "${var.ghes_url}/${var.ghes_org}" : "https://github.com/${var.ghes_org}"
}
