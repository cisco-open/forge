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
      && contains([for rule in signalfx_detector.k8s_otel_no_data.rule : rule.severity], "Critical")
    )
    error_message = "K8s no-data detector must keep cluster scoping, fill duration, team, tags, and critical severity."
  }

  assert {
    condition = (
      signalfx_detector.k8s_otel_collector_health.name == "Forge Prod K8S Splunk OTel collector health"
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "filter('k8s.namespace.name', 'splunk-otel')")
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "filter('k8s.pod.name', 'splunk-otel-collector*')")
      && strcontains(signalfx_detector.k8s_otel_collector_health.program_text, "running_collector_pods < 2")
      && length(signalfx_detector.k8s_otel_collector_health.rule) == 4
    )
    error_message = "K8s collector detector must keep collector namespace, pod filter, min-running threshold, and all collector rules."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.k8s_tenant_pods_pending.program_text, "filter('k8s.namespace.name', 'tenant-a') or filter('k8s.namespace.name', 'tenant-b')")
      && strcontains(signalfx_detector.k8s_other_namespace_pods_unhealthy.program_text, "not filter('k8s.namespace.name', 'kube-system', 'karpenter', 'splunk-otel', 'tenant-a', 'tenant-b')")
      && strcontains(signalfx_detector.k8s_platform_pods_unhealthy.program_text, "filter('k8s.namespace.name', 'kube-system') or filter('k8s.namespace.name', 'karpenter')")
    )
    error_message = "K8s detectors must keep separate tenant, other-namespace, and platform namespace filters."
  }
}
