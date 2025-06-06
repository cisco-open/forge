locals {
  config       = yamldecode(file("config.yaml"))
  splunk_cloud = local.config.splunk_cloud
}
