output "detector_ids" {
  description = "Dependency detector IDs keyed by tenant for linking dashboard charts."
  value = {
    for tenant_name, detector in signalfx_detector.tenant_dependency_health :
    tenant_name => detector.id
  }
}
