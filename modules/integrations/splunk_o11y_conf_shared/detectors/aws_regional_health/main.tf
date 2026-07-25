locals {
  detector_tags = ["forgecicd", "aws", "regional-platform", "terraform"]

  configured_scope_definitions = [
    for variable in var.dynamic_variables : {
      property = variable.property
      required = variable.value_required
      values   = sort(distinct(concat(variable.values, variable.values_suggested)))
    }
  ]
  configured_scope_filters = [
    for variable in local.configured_scope_definitions :
    length(variable.values) > 0 ? "filter('${variable.property}', '${join("', '", variable.values)}')" : "filter('${variable.property}', '__forge_dynamic_scope_not_configured__')"
    if variable.required || length(variable.values) > 0
  ]
  configured_scope_filter = length(local.configured_scope_filters) > 0 ? join(" and ", local.configured_scope_filters) : "filter('sf_metric', '__forge_dynamic_scope_not_configured__')"

  aws_platform_filter = "(${local.configured_scope_filter})"
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
