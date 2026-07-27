locals {
  dependency_monitor_function_name = "splunk-dependency-monitor-${var.aws_region}"
  all_security_tags                = merge(var.default_tags, var.tags)
}
