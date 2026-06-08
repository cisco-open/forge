locals {
  config       = yamldecode(file("config.yml"))
  splunk_cloud = local.config.splunk_cloud
}
