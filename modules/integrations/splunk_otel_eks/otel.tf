resource "helm_release" "splunk_otel_collector" {
  name             = "splunk-otel-collector"
  repository       = "https://signalfx.github.io/splunk-otel-collector-chart"
  chart            = "splunk-otel-collector"
  version          = "0.126.0"
  namespace        = "splunk-otel-collector"
  create_namespace = true
  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "distribution"
    value = "eks"
  }

  set {
    name  = "splunkObservability.accessToken"
    value = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_eks"].secret_string
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "splunkObservability.realm"
    value = var.splunk_otel_collector.splunk_observability_realm
  }

  set {
    name  = "splunkPlatform.endpoint"
    value = var.splunk_otel_collector.splunk_platform_endpoint
  }

  set {
    name  = "splunkPlatform.index"
    value = var.splunk_otel_collector.splunk_platform_index
  }

  set {
    name  = "splunkPlatform.token"
    value = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_eks"].secret_string
  }

  set {
    name  = "gateway.enabled"
    value = var.splunk_otel_collector.gateway
  }

  set {
    name  = "splunkObservability.profilingEnabled"
    value = var.splunk_otel_collector.splunk_observability_profiling
  }

  set {
    name  = "environment"
    value = var.splunk_otel_collector.environment
  }

  set {
    name  = "agent.discovery.enabled"
    value = var.splunk_otel_collector.discovery
  }

  upgrade_install = true
  cleanup_on_fail = true
  timeout         = 1200
}
