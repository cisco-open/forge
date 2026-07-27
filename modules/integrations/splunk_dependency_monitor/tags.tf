locals {
  dependency_monitor_function_name = "splunk-dependency-monitor-${var.aws_region}"
  failed_invocations_queue_name    = "${local.dependency_monitor_function_name}-failed-invocations"
  all_security_tags                = merge(var.default_tags, var.tags)
}
