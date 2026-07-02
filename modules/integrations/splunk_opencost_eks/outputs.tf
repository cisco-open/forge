output "namespace" {
  value = "opencost"
}

output "release_name" {
  value = "opencost"
}

output "service_name" {
  value = "opencost"
}

output "service_account_name" {
  value = "opencost"
}

output "metrics_endpoint" {
  value = "http://opencost.opencost.svc.cluster.local:9003/metrics"
}

output "metrics_host" {
  value = "opencost.opencost.svc.cluster.local"
}

output "metrics_port" {
  value = 9003
}

output "metrics_path" {
  value = "/metrics"
}

output "prometheus_endpoint" {
  value = "http://prometheus-server.prometheus-system.svc.cluster.local:80"
}
