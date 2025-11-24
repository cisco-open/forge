resource "helm_release" "splunk_otel_collector" {
  name             = "splunk-otel-collector"
  repository       = "https://signalfx.github.io/splunk-otel-collector-chart"
  chart            = "splunk-otel-collector"
  version          = "0.140.0"
  namespace        = "splunk-otel-collector"
  create_namespace = true

  set = [
    {
      name  = "cloudProvider"
      value = "aws"
    },
    {
      name  = "distribution"
      value = "eks"
    },
    {
      name  = "splunkObservability.accessToken"
      value = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_eks"].secret_string
    },
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "splunkObservability.realm"
      value = var.splunk_otel_collector.splunk_observability_realm
    },
    {
      name  = "splunkPlatform.endpoint"
      value = var.splunk_otel_collector.splunk_platform_endpoint
    },
    {
      name  = "splunkPlatform.index"
      value = var.splunk_otel_collector.splunk_platform_index
    },
    {
      name  = "splunkPlatform.token"
      value = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_hec_token_eks"].secret_string
    },
    {
      name  = "gateway.enabled"
      value = var.splunk_otel_collector.gateway
    },
    {
      name  = "splunkObservability.profilingEnabled"
      value = var.splunk_otel_collector.splunk_observability_profiling
    },
    {
      name  = "environment"
      value = var.splunk_otel_collector.environment
    },
    {
      name  = "agent.discovery.enabled"
      value = var.splunk_otel_collector.discovery
    },
    {
      name  = "tolerations[0].operator"
      value = "Exists"
    }
  ]

  force_update    = true
  cleanup_on_fail = true
  timeout         = 1200
}
