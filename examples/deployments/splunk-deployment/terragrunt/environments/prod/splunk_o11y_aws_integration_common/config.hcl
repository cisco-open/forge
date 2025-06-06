locals {
  config                 = yamldecode(file("config.yaml"))
  integration_name       = local.config.integration_name
  integration_regions    = local.config.integration_regions
  splunk_api_url         = local.config.splunk_api_url
  splunk_organization_id = local.config.splunk_organization_id
}
