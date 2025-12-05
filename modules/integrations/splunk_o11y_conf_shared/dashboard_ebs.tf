resource "signalfx_time_chart" "byte_utilization_pct" {
  name = "Byte utilization %"

  description  = "Compares delivered bytes to maximum allowed for Nitro volumes"
  program_text = <<-EOF
A = data('EBSByteBalance%').mean(by=['AWSUniqueId']).publish(label='A')
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
  unit_prefix  = "Metric"
}

resource "signalfx_time_chart" "write_latency" {
  name         = "Write latency (ms/op)"
  description  = "Estimates average latency per write operation for troubleshooting"
  program_text = <<-EOF
A = data('VolumeTotalWriteTime').sum(by=['VolumeId']).publish(label='A', enable=False)
B = data('VolumeWriteOps').sum(by=['VolumeId']).publish(label='B', enable=False)
C = (A/B * 1000).publish(label='C', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "read_ops" {
  name         = "# Read ops"
  description  = "Displays reads performed per interval for EBS volume"
  program_text = <<-EOF
A = data('VolumeReadOps').sum().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "write_throughput" {
  name         = "Write throughput"
  description  = "Shows throughput of writes in bytes per time interval"
  program_text = <<-EOF
A = data('VolumeWriteBytes').rate().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "rw_bytes_breakdown" {
  name         = "Read/write bytes breakdown"
  description  = "Compares total bytes read to bytes written across timeline"
  program_text = <<-EOF
A = data('VolumeReadBytes').sum().publish(label='A', enable=True)
B = data('VolumeWriteBytes').sum().publish(label='B', enable=True)
EOF
  plot_type    = "AreaChart"
  color_by     = "Dimension"
  stacked      = true
}

resource "signalfx_time_chart" "read_latency" {
  name         = "Read latency (ms/op)"
  description  = "Estimates average latency per read operation as efficiency measure"
  program_text = <<-EOF
A = data('VolumeTotalReadTime').sum(by=['VolumeId']).publish(label='A', enable=False)
B = data('VolumeReadOps').sum(by=['VolumeId']).publish(label='B', enable=False)
C = (A/B*1000).publish(label='C', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "read_throughput" {
  name         = "Read throughput"
  description  = "Shows throughput of reads in bytes per time interval"
  program_text = <<-EOF
A = data('VolumeReadBytes').rate().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_single_value_chart" "state" {
  name         = "State"
  description  = "Indicates availability and current status for workload visibility"
  program_text = <<-EOF
A = data('VolumeReadOps').count(by=['aws_state']).publish(label='A', enable=True)
EOF
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "total_read_time" {
  name         = "Total read time"
  description  = "Total seconds spent in servicing read operations"
  program_text = <<-EOF
A = data('VolumeTotalReadTime').sum().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "latency_op" {
  name         = "Latency/op (ms)"
  description  = ""
  program_text = <<-EOF
A = data('VolumeWriteOps', filter=filter('namespace', 'AWS/EBS') and filter('VolumeId', 'vol-46dcc55f') and filter('stat','sum'), extrapolation='zero', rollup='rate').scale(60).publish(label='A')
B = data('VolumeTotalWriteTime', filter=filter('namespace','AWS/EBS') and filter('VolumeId','vol-46dcc55f') and filter('stat','sum'), extrapolation='zero', rollup='rate').scale(60).publish(label='B', enable=False)
C = data('VolumeReadOps', filter=filter('namespace','AWS/EBS') and filter('VolumeId','vol-46dcc55f') and filter('stat','sum'), extrapolation='zero', rollup='rate').scale(60).publish(label='C')
D = data('VolumeTotalReadTime', filter=filter('namespace','AWS/EBS') and filter('VolumeId','vol-46dcc55f') and filter('stat','sum'), extrapolation='zero', rollup='rate').scale(60).publish(label='D', enable=False)
E = (B/A).scale(1000).publish(label='E')
F = (D/C).scale(1000).publish(label='F')
EOF
  plot_type    = "ColumnChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "total_write_time" {
  name         = "Total write time"
  description  = "Total seconds spent in servicing write operations"
  program_text = <<-EOF
A = data('VolumeTotalWriteTime').sum().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "read_vs_write_ops" {
  name         = "Read vs write ops"
  description  = "Visualizes relative load of read and write ops over time"
  program_text = <<-EOF
A = data('VolumeReadOps').sum().publish(label='A', enable=True)
B = data('VolumeWriteOps').sum().publish(label='B', enable=True)
EOF
  plot_type    = "AreaChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "avg_queue_length" {
  name         = "Average queue length"
  description  = "Measures operations awaiting completion, highlighting saturation"
  program_text = <<-EOF
A = data('VolumeQueueLength').mean().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "idle_time" {
  name         = "Idle time"
  description  = "Indicates when disk is idle and not serving I/O"
  program_text = <<-EOF
A = data('VolumeIdleTime').sum().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}

resource "signalfx_time_chart" "write_ops" {
  name         = "# Write ops"
  description  = "Displays writes performed per interval for EBS volume"
  program_text = <<-EOF
A = data('VolumeWriteOps').sum().publish(label='A', enable=True)
EOF
  plot_type    = "LineChart"
  color_by     = "Dimension"
}
resource "signalfx_dashboard" "ebs" {
  name            = "EBS"
  description     = "EBS Volume Performance Metrics"
  dashboard_group = signalfx_dashboard_group.forgecicd.id

  variable {
    property               = "aws_tag_TenantName"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = var.dashboard_variables.lambda.tenant_names
    restricted_suggestions = true
  }

  dynamic "variable" {
    for_each = var.dashboard_variables.lambda.dynamic_variables
    iterator = var_def

    content {
      property               = var_def.value.property
      alias                  = var_def.value.alias
      description            = var_def.value.description
      values                 = var_def.value.values
      value_required         = var_def.value.value_required
      values_suggested       = var_def.value.values_suggested
      restricted_suggestions = var_def.value.restricted_suggestions
    }
  }

  chart {
    chart_id = signalfx_single_value_chart.state.id
    column   = 0
    row      = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.read_ops.id
    column   = 4
    row      = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.write_ops.id
    column   = 8
    row      = 0
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.write_latency.id
    column   = 8
    row      = 1
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.read_latency.id
    column   = 4
    row      = 1
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.latency_op.id
    column   = 0
    row      = 1
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.read_vs_write_ops.id
    column   = 0
    row      = 2
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.write_throughput.id
    column   = 8
    row      = 2
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.read_throughput.id
    column   = 4
    row      = 2
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.rw_bytes_breakdown.id
    column   = 0
    row      = 3
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.total_read_time.id
    column   = 4
    row      = 3
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.total_write_time.id
    column   = 8
    row      = 3
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.byte_utilization_pct.id
    column   = 0
    row      = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.idle_time.id
    column   = 8
    row      = 4
    width    = 4
    height   = 1
  }

  chart {
    chart_id = signalfx_time_chart.avg_queue_length.id
    column   = 4
    row      = 4
    width    = 4
    height   = 1
  }

}
