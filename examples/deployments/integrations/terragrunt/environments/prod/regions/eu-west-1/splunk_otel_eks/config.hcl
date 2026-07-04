locals {
  config                = yamldecode(file("config.yml"))
  cluster_name          = local.config.cluster_name
  splunk_otel_collector = local.config.splunk_otel_collector
}
