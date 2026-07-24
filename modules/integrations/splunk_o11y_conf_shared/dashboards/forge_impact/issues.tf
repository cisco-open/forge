locals {
  issue_window = "Args.get('ui.dashboard_window', '1h')"
}

resource "signalfx_list_chart" "top_tenants_lambda_errors" {
  name        = "Top 10 tenants: Lambda errors"
  description = "Lambda errors over the selected window. Use the tenant property to continue investigation in the Lambdas dashboard."

  program_text = "A = data('Errors', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('aws_function_version', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).sum(over=${local.issue_window}).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "Lambda errors"
    label        = "A"
    value_suffix = " errors"
  }
}

resource "signalfx_list_chart" "top_tenants_lambda_throttles" {
  name        = "Top 10 tenants: Lambda throttles"
  description = "Lambda throttles over the selected window. Use the tenant property to continue investigation in the Lambdas dashboard."

  program_text = "A = data('Throttles', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('aws_function_version', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).sum(over=${local.issue_window}).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "Lambda throttles"
    label        = "A"
    value_suffix = " throttles"
  }
}

resource "signalfx_list_chart" "top_tenants_ec2_memory" {
  name        = "Top 10 tenants: EC2 memory utilization"
  description = "Highest current runner-host memory utilization per tenant. Values at or above 99% are critical."

  program_text = <<-EOF
used = data('system.memory.usage', filter=(${local.ec2_tenant_filter}) and filter('cloud.platform', 'aws_ec2') and filter('state', 'used'), rollup='latest').sum(by=['aws_tag_TenantName', 'host.name'])
total = data('system.memory.usage', filter=(${local.ec2_tenant_filter}) and filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free', 'cached', 'buffered'), rollup='latest').sum(by=['aws_tag_TenantName', 'host.name'])
A = ((used / total) * 100).max(by=['aws_tag_TenantName']).top(count=10).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  color_scale {
    color = "orange"
    gte   = 90
    lt    = 99
  }
  color_scale {
    color = "red"
    gte   = 99
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "EC2 memory utilization"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "top_tenants_ec2_cpu" {
  name        = "Top 10 tenants: EC2 CPU utilization"
  description = "Highest current EC2 runner CPU utilization per tenant."

  program_text = "A = data('CPUUtilization', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), rollup='latest').mean(by=['aws_tag_TenantName', 'aws_instance_id']).max(by=['aws_tag_TenantName']).top(count=10).publish(label='A')"

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  color_scale {
    color = "orange"
    gte   = 90
    lt    = 99
  }
  color_scale {
    color = "red"
    gte   = 99
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "EC2 CPU utilization"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "top_tenants_k8s_pending_pods" {
  name        = "Top 10 tenants: K8S pending pods"
  description = "Current pending pod count by Forge tenant namespace."

  program_text = "A = data('k8s.pod.phase', filter=(${local.k8s_tenant_namespace_filter}), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.namespace.name']).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }

  viz_options {
    display_name = "K8S pending pods"
    label        = "A"
    value_suffix = " pending"
  }
}

resource "signalfx_list_chart" "top_tenants_k8s_failed_pods" {
  name        = "Top 10 tenants: K8S failed or unknown pods"
  description = "Current failed or unknown pod count by Forge tenant namespace."

  program_text = "A = data('k8s.pod.phase', filter=(${local.k8s_tenant_namespace_filter}), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).count(by=['k8s.namespace.name']).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }

  viz_options {
    display_name = "K8S failed or unknown pods"
    label        = "A"
    value_suffix = " failed/unknown"
  }
}

resource "signalfx_list_chart" "top_tenants_sqs_backlog" {
  name        = "Top 10 tenants: SQS visible backlog"
  description = "Current visible SQS messages summed by Forge tenant."

  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/SQS') and filter('QueueName', '*') and filter('stat', 'mean'), rollup='latest').sum(by=['aws_tag_TenantName']).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "SQS visible backlog"
    label        = "A"
    value_suffix = " messages"
  }
}

resource "signalfx_list_chart" "top_tenants_sqs_dlq_backlog" {
  name        = "Top 10 tenants: SQS dead-letter backlog"
  description = "Current visible messages in dead-letter queues summed by Forge tenant."

  program_text = "A = data('ApproximateNumberOfMessagesVisible', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/SQS') and filter('QueueName', '*dead-letter*', '*dlq*', '*DLQ*') and filter('stat', 'mean'), rollup='latest').sum(by=['aws_tag_TenantName']).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "SQS dead-letter backlog"
    label        = "A"
    value_suffix = " DLQ messages"
  }
}

resource "signalfx_list_chart" "top_tenants_dynamodb_throttles" {
  name        = "Top 10 tenants: DynamoDB throttled requests"
  description = "DynamoDB throttled requests over the selected window, summed by Forge tenant."

  program_text = "A = data('ThrottledRequests', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).sum(over=${local.issue_window}).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "DynamoDB throttled requests"
    label        = "A"
    value_suffix = " throttled"
  }
}

resource "signalfx_list_chart" "top_tenants_dynamodb_system_errors" {
  name        = "Top 10 tenants: DynamoDB system errors"
  description = "DynamoDB HTTP 500 errors over the selected window, summed by Forge tenant."

  program_text = "A = data('SystemErrors', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/DynamoDB') and filter('stat', 'sum') and filter('TableName', '*') and filter('Operation', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName']).sum(over=${local.issue_window}).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "DynamoDB system errors"
    label        = "A"
    value_suffix = " errors"
  }
}

resource "signalfx_list_chart" "top_tenants_ebs_queue_length" {
  name        = "Top 10 tenants: EBS queue length"
  description = "Highest current EBS volume queue length per Forge tenant."

  program_text = "A = data('VolumeQueueLength', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/EBS') and filter('stat', 'mean') and filter('VolumeId', '*'), rollup='latest').mean(by=['aws_tag_TenantName', 'VolumeId']).max(by=['aws_tag_TenantName']).above(0).top(count=10).publish(label='A')"

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "EBS queue length"
    label        = "A"
  }
}
