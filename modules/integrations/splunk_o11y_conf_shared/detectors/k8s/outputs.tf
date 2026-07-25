output "detector_ids" {
  description = "Kubernetes detector IDs for linking the matching dashboard charts."
  value = {
    otel_no_data            = signalfx_detector.k8s_otel_no_data.id
    otel_collector_health   = signalfx_detector.k8s_otel_collector_health.id
    tenant_pods_pending     = signalfx_detector.k8s_tenant_pods_pending.id
    platform_pods_unhealthy = signalfx_detector.k8s_platform_pods_unhealthy.id
  }
}
