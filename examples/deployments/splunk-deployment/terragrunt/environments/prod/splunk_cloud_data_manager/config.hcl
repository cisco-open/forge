locals {
  config                       = yamldecode(file("config.yaml"))
  cloudformation_s3_config     = local.config.cloudformation_s3_config
  cloudwatch_log_groups_config = local.config.cloudwatch_log_groups_config
  security_metadata_config     = local.config.security_metadata_config
  splunk_cloud                 = local.config.splunk_cloud
}
