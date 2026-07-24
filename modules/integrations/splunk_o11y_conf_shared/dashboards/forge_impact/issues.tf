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
    color = "green"
    lt    = 90
  }
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
    color = "green"
    lt    = 90
  }
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

resource "signalfx_list_chart" "top_tenants_ec2_disk" {
  name        = "Top 10 tenants: EC2 disk utilization"
  description = "Highest current filesystem utilization on a Forge EC2 runner host per tenant."

  program_text = <<-EOF
used = data('system.filesystem.usage', filter=(${local.ec2_tenant_filter}) and filter('cloud.platform', 'aws_ec2') and filter('state', 'used'), rollup='latest').sum(by=['aws_tag_TenantName', 'host.id'])
free = data('system.filesystem.usage', filter=(${local.ec2_tenant_filter}) and filter('cloud.platform', 'aws_ec2') and filter('state', 'free'), rollup='latest').sum(by=['aws_tag_TenantName', 'host.id'])
A = ((used / (used + free)) * 100).max(by=['aws_tag_TenantName']).top(count=10).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  color_scale {
    color = "green"
    lt    = 80
  }
  color_scale {
    color = "orange"
    gte   = 80
    lt    = 90
  }
  color_scale {
    color = "red"
    gte   = 90
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "EC2 disk utilization"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "top_tenants_ec2_status_failures" {
  name        = "Top 10 tenants: EC2 status check failures"
  description = "Highest instance or system status-check failure count on a Forge EC2 runner per tenant over the selected window."

  program_text = "A = data('StatusCheckFailed', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/EC2') and filter('stat', 'sum') and filter('aws_instance_id', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName', 'aws_instance_id']).sum(over=${local.issue_window}).max(by=['aws_tag_TenantName']).above(0).top(count=10).publish(label='A')"

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  color_scale {
    color = "green"
    lt    = 1
  }
  color_scale {
    color = "red"
    gte   = 1
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "EC2 status check failures"
    label        = "A"
    value_suffix = " failed checks"
  }
}

resource "signalfx_list_chart" "top_tenants_k8s_restarts" {
  name        = "Top 10 tenants: K8S container restarts"
  description = "Positive container restart deltas in Forge tenant namespaces over the selected window."

  program_text = "A = data('k8s.container.restarts', filter=(${local.k8s_tenant_namespace_filter}) and filter('k8s.container.name', '*'), rollup='latest').max(by=['k8s.namespace.name', 'k8s.pod.name', 'k8s.container.name']).delta().sum(by=['k8s.namespace.name']).sum(over=${local.issue_window}).above(0).top(count=10).publish(label='A')"

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  color_scale {
    color = "green"
    lt    = 1
  }
  color_scale {
    color = "red"
    gte   = 1
  }

  legend_options_fields {
    enabled  = true
    property = "k8s.namespace.name"
  }

  viz_options {
    display_name = "K8S container restarts"
    label        = "A"
    value_suffix = " restarts"
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

resource "signalfx_list_chart" "top_tenants_ebs_iops_exceeded" {
  name        = "Top 10 tenants: EBS IOPS limit exceeded"
  description = "Highest EBS provisioned-IOPS exceeded count per Forge tenant over the selected window."

  program_text = "A = data('VolumeIOPSExceededCheck', filter=(${local.ec2_tenant_filter}) and filter('namespace', 'AWS/EBS') and filter('stat', 'sum') and filter('VolumeId', '*'), rollup='sum', extrapolation='zero').sum(by=['aws_tag_TenantName', 'VolumeId']).sum(over=${local.issue_window}).max(by=['aws_tag_TenantName']).above(0).top(count=10).publish(label='A')"

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 3600
  unit_prefix             = "Metric"

  color_scale {
    color = "green"
    lt    = 1
  }
  color_scale {
    color = "red"
    gte   = 1
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }

  viz_options {
    display_name = "EBS IOPS limit exceeded"
    label        = "A"
    value_suffix = " exceeded checks"
  }
}
