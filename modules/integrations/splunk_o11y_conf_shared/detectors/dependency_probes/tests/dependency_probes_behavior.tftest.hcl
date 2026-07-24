mock_provider "signalfx" {
  mock_resource "signalfx_detector" {}
}

variables {
  detector_notifications = []
  detector_name_prefix   = "Forge Prod"
  team                   = "forge-team"
  tenant_names           = ["tenant-a", "tenant-b"]
  detector_config = {
    failure_duration                   = "10m"
    no_data_duration                   = "15m"
    no_data_fill_duration              = "4h"
    rate_limit_duration                = "10m"
    rate_limit_remaining_pct_threshold = 10
  }
}

run "creates_one_dependency_detector_per_tenant" {
  command = plan

  assert {
    condition = (
      signalfx_detector.tenant_dependency_health["tenant-a"].name == "Forge Prod tenant tenant-a dependency health"
      && signalfx_detector.tenant_dependency_health["tenant-b"].name == "Forge Prod tenant tenant-b dependency health"
    )
    error_message = "Dependency probes must create a distinct detector for every configured tenant."
  }

  assert {
    condition = (
      length(signalfx_detector.tenant_dependency_health["tenant-a"].rule) == 4
      && length(signalfx_detector.tenant_dependency_health["tenant-b"].rule) == 4
    )
    error_message = "Every tenant detector must keep no-data, SSM, GitHub availability, and rate-limit rules."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "forge.dependency.probe_executed")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "forge.dependency.availability")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "forge.dependency.rate_limit_remaining_pct")
      && !strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "filter('namespace'")
    )
    error_message = "Tenant detectors must consume direct Splunk metrics without a CloudWatch namespace filter."
  }
}
