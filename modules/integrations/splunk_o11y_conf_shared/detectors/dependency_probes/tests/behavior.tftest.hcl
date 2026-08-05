mock_provider "signalfx" {
  mock_resource "signalfx_detector" {}
}

variables {
  detector_notifications  = []
  detector_name_prefix    = "Forge Prod"
  lambda_dimension_filter = "filter('namespace', 'AWS/Lambda') and filter('Resource', '*') and (not filter('ExecutedVersion', '*'))"
  team                    = "forge-team"
  tenant_names            = ["tenant-a", "tenant-b"]
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
      signalfx_detector.tenant_dependency_health["tenant-a"].name == "Forge Prod tenant tenant-a health"
      && signalfx_detector.tenant_dependency_health["tenant-b"].name == "Forge Prod tenant tenant-b health"
    )
    error_message = "Dependency probes must create a distinct detector for every configured tenant."
  }

  assert {
    condition = (
      length(signalfx_detector.tenant_dependency_health["tenant-a"].rule) == 16
      && length(signalfx_detector.tenant_dependency_health["tenant-b"].rule) == 16
    )
    error_message = "Every tenant detector must keep four dependency rules plus twelve actionable workload-health rules."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "forge.dependency.probe_executed")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "forge.dependency.availability")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "forge.dependency.rate_limit_remaining_pct")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "filter('aws_tag_TenantName', 'tenant-a')")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "filter('aws_tag_ForgeModuleRef', '*')")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "filter('Resource', '*')")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "not filter('ExecutedVersion', '*')")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "sum(by=['aws_region', 'aws_function_name', 'aws_tag_ForgeModuleRef'])")
      && !strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "aws_function_version")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "lambda_error_rate >= 5")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "filter('QueueName', '*dead-letter*', '*dead_letter*', '*dlq*', '*DLQ*')")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "filter('k8s.namespace.name', 'tenant-a')")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "StatusCheckFailed")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "ec2_disk_utilization > 80, '10m'")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "ec2_memory_utilization > 90, '10m'")
      && strcontains(signalfx_detector.tenant_dependency_health["tenant-a"].program_text, "VolumeIOPSExceededCheck")
    )
    error_message = "Tenant detectors must combine direct dependency telemetry with tenant-scoped AWS and Kubernetes health signals."
  }
}
