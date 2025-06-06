locals {
  config            = yamldecode(file("config.yaml"))
  splunk_ingest_url = local.config.splunk_ingest_url
  template_url      = local.config.template_url
}
