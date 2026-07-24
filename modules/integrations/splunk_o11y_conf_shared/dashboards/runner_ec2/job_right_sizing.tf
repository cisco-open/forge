locals {
  ec2_runner_job_identity       = "['aws_tag_TenantName', 'aws_instance_type', 'aws_instance_id', 'aws_tag_ghr_job_url', 'aws_tag_ghr_workflow_url', 'aws_tag_ghr_runner_labels', 'aws_tag_ghr_repository', 'aws_tag_ghr_workflow', 'aws_tag_ghr_job', 'aws_tag_ghr_created_by']"
  ec2_runner_class_job_identity = "['aws_tag_TenantName', 'aws_instance_type', 'aws_tag_ghr_runner_labels', 'aws_tag_ghr_repository', 'aws_tag_ghr_workflow', 'aws_tag_ghr_job']"
}

resource "signalfx_list_chart" "job_runs_high_peak_cpu" {
  name        = "Job runs: high peak CPU utilization (%)"
  description = "Upgrade evidence: job executions whose 24-hour peak CPU reached at least 85%. Review repeated workflow/job runner-class evidence before resizing."

  program_text = <<-EOF
jobs = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*'), rollup='average').max(over='24h').mean(by=${local.ec2_runner_job_identity})
A = jobs.above(85, inclusive=True).top(count=20).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 86400

  color_scale {
    color = "blue"
    lt    = 85
  }
  color_scale {
    color = "orange"
    gte   = 85
    lt    = 95
  }
  color_scale {
    color = "red"
    gte   = 95
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_runner_labels"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job_url"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_created_by"
  }

  viz_options {
    display_name = "24h peak CPU"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "job_runs_low_peak_cpu" {
  name        = "Job runs: low peak CPU utilization (%)"
  description = "Downgrade candidates: job executions whose 24-hour peak CPU stayed below 20%. Require repeated low CPU and memory evidence before resizing."

  program_text = <<-EOF
jobs = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*'), rollup='average').max(over='24h').mean(by=${local.ec2_runner_job_identity})
A = jobs.below(20).bottom(count=20).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "+value"
  time_range              = 86400

  color_scale {
    color = "green"
    lt    = 10
  }
  color_scale {
    color = "yellow"
    gte   = 10
    lt    = 20
  }
  color_scale {
    color = "blue"
    gte   = 20
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_runner_labels"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job_url"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_created_by"
  }

  viz_options {
    display_name = "24h peak CPU"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "job_runs_high_peak_memory" {
  name        = "Job runs: high peak memory utilization (%)"
  description = "Upgrade evidence from hosts with the OTel agent: job executions whose 24-hour peak memory reached at least 85%."

  program_text = <<-EOF
used = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=${local.ec2_runner_job_identity})
total = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free', 'cached', 'buffered') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=${local.ec2_runner_job_identity})
jobs = ((used / total) * 100).max(over='24h')
A = jobs.above(85, inclusive=True).top(count=20).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 86400

  color_scale {
    color = "blue"
    lt    = 85
  }
  color_scale {
    color = "orange"
    gte   = 85
    lt    = 95
  }
  color_scale {
    color = "red"
    gte   = 95
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_runner_labels"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job_url"
  }

  viz_options {
    display_name = "24h peak memory"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "job_runs_low_peak_memory" {
  name        = "Job runs: low peak memory utilization (%)"
  description = "Downgrade evidence from hosts with the OTel agent: job executions whose 24-hour peak memory stayed below 40%."

  program_text = <<-EOF
used = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=${local.ec2_runner_job_identity})
total = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free', 'cached', 'buffered') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=${local.ec2_runner_job_identity})
jobs = ((used / total) * 100).max(over='24h')
A = jobs.below(40).bottom(count=20).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "+value"
  time_range              = 86400

  color_scale {
    color = "green"
    lt    = 20
  }
  color_scale {
    color = "yellow"
    gte   = 20
    lt    = 40
  }
  color_scale {
    color = "blue"
    gte   = 40
  }

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_runner_labels"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job_url"
  }

  viz_options {
    display_name = "24h peak memory"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "runner_classes_by_mean_peak_cpu" {
  name        = "Runner classes: mean job peak CPU utilization (%)"
  description = "Repeated evidence grouped by tenant, repository, workflow, job, runner labels, and EC2 instance type. Use with memory evidence when changing runner class."

  program_text = <<-EOF
jobs = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*'), rollup='average').max(over='24h').mean(by=${local.ec2_runner_class_job_identity})
A = jobs.top(count=20).publish(label='A')
EOF

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 86400

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_runner_labels"
  }

  viz_options {
    display_name = "Mean 24h peak CPU"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "runner_classes_by_mean_peak_memory" {
  name        = "Runner classes: mean job peak memory utilization (%)"
  description = "Repeated memory evidence from hosts with the OTel agent, grouped by tenant, repository, workflow, job, runner labels, and EC2 instance type."

  program_text = <<-EOF
used = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=${local.ec2_runner_job_identity})
total = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free', 'cached', 'buffered') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=${local.ec2_runner_job_identity})
jobs = ((used / total) * 100).max(over='24h').mean(by=${local.ec2_runner_class_job_identity})
A = jobs.top(count=20).publish(label='A')
EOF

  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 86400

  legend_options_fields {
    enabled  = true
    property = "aws_tag_TenantName"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_runner_labels"
  }

  viz_options {
    display_name = "Mean 24h peak memory"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_list_chart" "job_runs_high_peak_filesystem" {
  name        = "Job runs: high peak filesystem utilization (%)"
  description = "EBS capacity evidence from hosts with the OTel agent: filesystems whose 24-hour peak utilization reached at least 80%."

  program_text = <<-EOF
filesystem_identity = ${replace(local.ec2_runner_job_identity, "]", ", 'mountpoint', 'device']")}
used = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=filesystem_identity)
free = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'free') and filter('aws_tag_TenantName', '*') and filter('aws_tag_ghr_job_url', '*')).sum(by=filesystem_identity)
jobs = ((used / (used + free)) * 100).max(over='24h')
A = jobs.above(80, inclusive=True).top(count=20).publish(label='A')
EOF

  color_by                = "Scale"
  hide_missing_values     = true
  max_precision           = 2
  secondary_visualization = "Sparkline"
  sort_by                 = "-value"
  time_range              = 86400

  color_scale {
    color = "blue"
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
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_repository"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_workflow"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = true
    property = "mountpoint"
  }
  legend_options_fields {
    enabled  = true
    property = "device"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_tag_ghr_job_url"
  }

  viz_options {
    display_name = "24h peak filesystem"
    label        = "A"
    value_suffix = "%"
  }
}
