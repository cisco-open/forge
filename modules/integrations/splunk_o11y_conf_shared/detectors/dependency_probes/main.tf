locals {
  detector_tags = ["forgecicd", "dependency-probe", "github", "terraform"]
}

resource "signalfx_detector" "tenant_dependency_health" {
  for_each = toset(var.tenant_names)

  name        = "${var.detector_name_prefix} tenant ${each.value} dependency health"
  description = "Monitors ${each.value} GitHub App authentication, organization runner API availability and rate-limit budget, regional SSM credential access, and probe telemetry."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
tenant_cycle = data('forge.dependency.probe_executed', filter=filter('TenantName', '${each.value}') and filter('Provider', 'Forge') and filter('CheckName', 'TenantCycle'), rollup='latest').max(by=['AWSRegion']).fill(value=0, duration='${var.detector_config.no_data_fill_duration}')
ssm_availability = data('forge.dependency.availability', filter=filter('TenantName', '${each.value}') and filter('Provider', 'AWS') and filter('CheckName', 'SSMCredentials'), rollup='min').min(by=['AWSRegion']).fill(value=0, duration='${var.detector_config.no_data_fill_duration}')
github_availability = data('forge.dependency.availability', filter=filter('TenantName', '${each.value}') and filter('Provider', 'GitHub'), rollup='min').min(by=['AWSRegion']).fill(value=0, duration='${var.detector_config.no_data_fill_duration}')
github_rate_limit_remaining_pct = data('forge.dependency.rate_limit_remaining_pct', filter=filter('TenantName', '${each.value}') and filter('Provider', 'GitHub') and filter('CheckName', 'OrgRunnersApi'), rollup='min').min(by=['AWSRegion']).fill(value=100, duration='${var.detector_config.no_data_fill_duration}')
detect(when(tenant_cycle < 1, '${var.detector_config.no_data_duration}')).publish('Tenant dependency probe has no data')
detect(when(ssm_availability < 1, '${var.detector_config.failure_duration}')).publish('Tenant GitHub App SSM credentials unavailable')
detect(when(github_availability < 1, '${var.detector_config.failure_duration}')).publish('Tenant GitHub API unavailable')
detect(when(github_rate_limit_remaining_pct < ${var.detector_config.rate_limit_remaining_pct_threshold}, '${var.detector_config.rate_limit_duration}')).publish('Tenant GitHub API rate-limit budget low')
EOF

  rule {
    description   = "Dependency probe telemetry missing for ${var.detector_config.no_data_duration}"
    severity      = "Warning"
    detect_label  = "Tenant dependency probe has no data"
    notifications = var.detector_notifications
  }

  rule {
    description   = "GitHub App SSM credentials unavailable for ${var.detector_config.failure_duration}"
    severity      = "Major"
    detect_label  = "Tenant GitHub App SSM credentials unavailable"
    notifications = var.detector_notifications
  }

  rule {
    description   = "GitHub authentication or organization runner API unavailable for ${var.detector_config.failure_duration}"
    severity      = "Major"
    detect_label  = "Tenant GitHub API unavailable"
    notifications = var.detector_notifications
  }

  rule {
    description   = "GitHub API rate-limit budget below ${var.detector_config.rate_limit_remaining_pct_threshold}% for ${var.detector_config.rate_limit_duration}"
    severity      = "Warning"
    detect_label  = "Tenant GitHub API rate-limit budget low"
    notifications = var.detector_notifications
  }
}
