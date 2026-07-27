mock_provider "signalfx" {
  mock_resource "signalfx_detector" {}
}

variables {
  detector_notifications = ["Email,forge@example.com"]
  detector_name_prefix   = "Forge Prod"
  dynamic_variables = [
    {
      property               = "k8s.cluster.name"
      alias                  = "cluster"
      description            = "Cluster"
      values                 = []
      value_required         = false
      values_suggested       = ["forge-euw1-dev"]
      restricted_suggestions = false
    }
  ]
  k8s_detector_config = {
    container_restarts_duration  = "10m"
    container_restarts_threshold = 3
    failed_pods_duration         = "15m"
    failed_pods_threshold        = 0
    otel_no_data_duration        = "15m"
    otel_no_data_fill_duration   = "20m"
    pending_pods_duration        = "10m"
    pending_pods_threshold       = 0
    platform_pods_duration       = "5m"
    platform_unhealthy_threshold = 0
  }
  k8s_otel_collector_config = {
    min_running_pods       = 2
    namespace              = "splunk-otel"
    no_running_duration    = "10m"
    pod_issue_duration     = "5m"
    pod_name_filter        = "splunk-otel-collector*"
    restart_duration       = "15m"
    restart_threshold      = 2
    stale_metrics_duration = "20m"
  }
  k8s_platform_namespaces = ["kube-system", "karpenter"]
  team                    = "forge-team"
  tenant_names            = ["tenant-a", "tenant-b"]
}

run "k8s_detector_scope_and_threshold_contract" {
  command = plan

  assert {
    condition = (
      signalfx_detector.k8s_otel_no_data.name == "Forge Prod K8S OTel no data"
      && signalfx_detector.k8s_otel_no_data.max_delay == 120
      && contains(signalfx_detector.k8s_otel_no_data.teams, "forge-team")
      && contains(signalfx_detector.k8s_otel_no_data.tags, "forgecicd")
      && strcontains(signalfx_detector.k8s_otel_no_data.program_text, "filter('k8s.cluster.name', 'forge-euw1-dev')")
      && strcontains(signalfx_detector.k8s_otel_no_data.program_text, "20m")
      && contains([for rule in signalfx_detector.k8s_otel_no_data.rule : rule.severity], "Warning")
    )
    error_message = "K8s no-data detector must keep cluster scoping, fill duration, team, tags, and non-paging warning severity."
  }

  assert {
    condition = (
      signalfx_detector.k8s_otel_collector_health.name == "Forge Prod K8S Splunk OTel collector health"
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "filter('k8s.namespace.name', 'splunk-otel')")
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "filter('k8s.pod.name', 'splunk-otel-collector*')")
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "running_collector_pods < 2")
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, ".delta().sum(over='15m')")
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, ".fill(value=0, duration='5m')")
      && !strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "'k8s.pod.name', 'k8s.container.name'")
      && length(signalfx_detector.k8s_otel_collector_health.rule) == 4
      && length([for rule in signalfx_detector.k8s_otel_collector_health.rule : rule if rule.severity == "Major"]) == 2
      && length([for rule in signalfx_detector.k8s_otel_collector_health.rule : rule if rule.severity == "Warning"]) == 2
    )
    error_message = "K8s collector detector must aggregate by cluster and keep two major availability rules plus two warning degradation rules."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.k8s_tenant_pods_pending.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && strcontains(signalfx_detector.k8s_tenant_pods_pending.program_text, "sum(by=['k8s.cluster.name', 'k8s.namespace.name'])")
      && !strcontains(signalfx_detector.k8s_tenant_pods_pending.program_text, "'k8s.pod.name'")
      && strcontains(signalfx_detector.k8s_tenant_pods_pending.program_text, ".fill(value=0, duration='10m')")
      && strcontains(signalfx_detector.k8s_platform_pods_unhealthy.program_text, "filter('k8s.namespace.name', 'kube-system') or filter('k8s.namespace.name', 'karpenter')")
      && !strcontains(signalfx_detector.k8s_platform_pods_unhealthy.program_text, "Platform pod pending")
      && strcontains(signalfx_detector.k8s_platform_pods_unhealthy.program_text, "platform_container_restarts")
      && strcontains(signalfx_detector.k8s_platform_pods_unhealthy.program_text, ".delta().sum(over='10m')")
      && strcontains(signalfx_detector.k8s_platform_pods_unhealthy.program_text, "platform_container_restarts > 3")
      && length(signalfx_detector.k8s_platform_pods_unhealthy.rule) == 2
      && length([for rule in signalfx_detector.k8s_platform_pods_unhealthy.rule : rule if rule.severity == "Major"]) == 1
      && length([for rule in signalfx_detector.k8s_platform_pods_unhealthy.rule : rule if rule.severity == "Warning"]) == 1
    )
    error_message = "K8s workload detectors must aggregate tenant pending pods by tenant and cover actionable platform pod failures and restart pressure."
  }
}

run "allows_tenant_health_to_own_pending_pod_notifications" {
  command = plan

  variables {
    tenant_pods_pending_notifications = []
  }

  assert {
    condition     = length(one(signalfx_detector.k8s_tenant_pods_pending.rule).notifications) == 0
    error_message = "The aggregate pending-pod detector must support suppressing notifications when tenant health detectors own the same signal."
  }
}
