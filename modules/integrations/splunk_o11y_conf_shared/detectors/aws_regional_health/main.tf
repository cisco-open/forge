locals {
  detector_tags = ["forgecicd", "aws", "regional-platform", "terraform"]

  aws_account_ids = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_account_id"
  ]))
  aws_regions = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_region"
  ]))
  product_family_names = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_tag_ProductFamilyName"
  ]))

  aws_account_filter = length(local.aws_account_ids) > 0 ? join(" or ", [
    for account_id in sort(local.aws_account_ids) : "filter('aws_account_id', '${account_id}')"
  ]) : "filter('aws_account_id', '__forge_aws_account_scope_not_configured__')"
  aws_region_filter = length(local.aws_regions) > 0 ? join(" or ", [
    for aws_region in sort(local.aws_regions) : "filter('aws_region', '${aws_region}')"
  ]) : "filter('aws_region', '__forge_aws_region_scope_not_configured__')"
  product_family_filter = length(local.product_family_names) > 0 ? join(" or ", [
    for product_family_name in sort(local.product_family_names) : "filter('aws_tag_ProductFamilyName', '${product_family_name}')"
  ]) : "filter('aws_tag_ProductFamilyName', '__forge_product_family_scope_not_configured__')"

  aws_platform_filter = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter})"
  build_queue_filter  = "filter('QueueName', '*-queued-builds') and (not filter('QueueName', '*_dead_letter'))"
}

resource "signalfx_detector" "aws_regional_platform_health" {
  name        = "${var.detector_name_prefix} AWS regional platform health"
  description = "Monitors regional Forge queued-build backlog, oldest-message age, and dead-letter queue activity."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
queue_oldest_age = data('ApproximateAgeOfOldestMessage', filter=(${local.aws_platform_filter}) and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.build_queue_filter})).max(over='5m').max(by=['aws_region'])
queue_visible_messages = data('ApproximateNumberOfMessagesVisible', filter=(${local.aws_platform_filter}) and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.build_queue_filter})).max(over='5m').sum(by=['aws_region'])
dlq_sends = data('NumberOfMessagesSent', filter=(${local.aws_platform_filter}) and filter('namespace', 'AWS/SQS') and filter('stat', 'sum') and filter('QueueName', '*_dead_letter'), rollup='sum').sum(over='5m').sum(by=['aws_region'])
detect(when(queue_oldest_age > 300, '10m'), off=when(queue_oldest_age < 60, '15m')).publish('Build queue oldest age major')
detect(when((queue_oldest_age > 75) and (queue_visible_messages > 10), '10m'), off=when(queue_oldest_age < 60, '15m')).publish('Build queue backlog warning')
detect(when(dlq_sends > 0)).publish('Queued-build DLQ activity')
EOF

  rule {
    description   = "Queued-build oldest-message age above 300 seconds for 10 minutes"
    severity      = "Major"
    detect_label  = "Build queue oldest age major"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Queued-build oldest-message age above 75 seconds and visible backlog above 10 for 10 minutes"
    severity      = "Warning"
    detect_label  = "Build queue backlog warning"
    notifications = var.detector_notifications
  }

  rule {
    description   = "At least one message sent to a queued-build dead-letter queue in five minutes"
    severity      = "Major"
    detect_label  = "Queued-build DLQ activity"
    notifications = var.detector_notifications
  }
}
