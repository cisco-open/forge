resource "signalfx_time_chart" "chart_disk_ops" {
  name = "# Disk ops"

  program_text = <<-EOF
A = data('^aws.ec2.disk.ops.write.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='A')
B = data('^aws.ec2.disk.ops.read.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='B')
EOF

  plot_type                 = "ColumnChart"
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  axes_precision = 0

  axis_left {
    min_value = 0
  }
  axis_right {
    min_value = 0
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "Write ops"
    label        = "A"
  }
  viz_options {
    axis         = "right"
    color        = "orange"
    display_name = "Read ops"
    label        = "B"
  }
}

resource "signalfx_time_chart" "chart_total_memory_overview_bytes" {
  name        = "Total memory overview (bytes)"
  description = "From hosts with agent installed"

  program_text = <<-EOF
C = data('system.memory.usage', filter=filter('state', 'free') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='C')
F = data('system.memory.usage', filter=filter('state', 'used') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='F')
A = data('system.memory.usage', filter=filter('state', 'buffered') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='A')
B = data('system.memory.usage', filter=filter('state', 'cached') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='B')
D = data('system.memory.usage', filter=filter('state', 'slab_reclaimable') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='D')
E = data('system.memory.usage', filter=filter('state', 'slab_unreclaimable') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='E')
EOF

  plot_type = "AreaChart"

  axes_precision            = 4
  on_chart_legend_dimension = "plot_label"
  stacked                   = true
  unit_prefix               = "Binary"

  time_range = 3600

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "Cached"
    label        = "B"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "emerald"
    display_name = "Free"
    label        = "C"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "Unreclaimable"
    label        = "E"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Used"
    label        = "F"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "violet"
    display_name = "Reclaimable"
    label        = "D"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "yellow"
    display_name = "Buffered"
    label        = "A"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "chart_network_out_bytes_vs_24h_change" {
  name = "Network out (bytes) vs. 24h change (%)"

  program_text = <<-EOF
A = data('^aws.ec2.network.io.transmit.total', extrapolation='last_value', maxExtrapolations=5).sum().mean(over='1h').publish(label='A')
B = (A).timeshift('1d').publish(label='B', enable=False)
C = (A/B-1).scale(100).publish(label='C')
EOF

  plot_type = "ColumnChart"

  axes_precision            = 0
  unit_prefix               = "Binary"
  on_chart_legend_dimension = "plot_label"

  time_range = 3600

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    display_name = "A - timeshift 1d"
    label        = "B"
  }
  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "Network out"
    label        = "A"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "right"
    color        = "orange"
    display_name = "24h change (%)"
    label        = "C"
    plot_type    = "LineChart"
  }
}

resource "signalfx_time_chart" "chart_network_out_bytes" {
  name        = "Network out (bytes)"
  description = "Percentile distribution across all active hosts"

  program_text = <<-EOF
A = data('^aws.ec2.network.io.transmit.total', extrapolation='last_value', maxExtrapolations=5).publish(label='A', enable=False)
B = (A).min().publish(label='B')
C = (A).percentile(pct=10).publish(label='C')
D = (A).percentile(pct=50).publish(label='D')
E = (A).percentile(pct=90).publish(label='E')
F = (A).max().publish(label='F')
EOF

  plot_type = "AreaChart"

  axes_precision            = 0
  unit_prefix               = "Binary"
  on_chart_legend_dimension = "plot_label"

  time_range = 3600

  axis_left {
    min_value = 0
    label     = "Bytes"
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    display_name = "Network bytes out"
    label        = "A"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "Median"
    label        = "D"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "chartreuse"
    display_name = "Min"
    label        = "B"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "P90"
    label        = "E"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Max"
    label        = "F"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "yellowgreen"
    display_name = "P10"
    label        = "C"
    value_unit   = "Byte"
  }
}

resource "signalfx_list_chart" "chart_top_instances_by_cpu_utilization" {
  name        = "Top instances by CPU utilization (%)"
  description = "By AWSUniqueId"

  program_text = "A = data('^aws.ec2.cpu.utilization', extrapolation='last_value', maxExtrapolations=5).mean(by=['AWSUniqueId']).top(count=5).publish(label='A')"

  sort_by = "-value"

  color_by                = "Scale"
  refresh_interval        = 60
  max_precision           = 4
  time_range              = 900
  secondary_visualization = "None"

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_instance_id"
  }

  viz_options {
    display_name = "Top instances by CPU utilization"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "chart_disk_utilization" {
  name        = "Disk utilization (%)"
  description = "Percentile distribution across active hosts with agent installed"

  program_text = <<-EOF
B = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used')).publish(label='B', enable=False)
C = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'free')).publish(label='C', enable=False)
D = ((B/(B+C))*100).mean(by=['AWSUniqueId']).publish(label='D', enable=False)
E = (D).min().publish(label='E')
F = (D).percentile(pct=10).publish(label='F')
G = (D).percentile(pct=50).publish(label='G')
H = (D).percentile(pct=90).publish(label='H')
I = (D).max().publish(label='I')
A = alerts(autodetect_id='F6cykK5AYAA', filter=filter('aws_tag_ProductFamilyName', 'Forge MT')).publish(label='A')
EOF

  plot_type = "AreaChart"

  axes_precision = 0

  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  event_options {
    display_name = "Autodetect alerts"
    label        = "A"
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_id"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
  legend_options_fields {
    enabled  = true
    property = "host.image.id"
  }
  legend_options_fields {
    enabled  = true
    property = "os.type"
  }
  legend_options_fields {
    enabled  = true
    property = "type"
  }
  legend_options_fields {
    enabled  = true
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "host.type"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.availability_zone"
  }
  legend_options_fields {
    enabled  = true
    property = "mountpoint"
  }
  legend_options_fields {
    enabled  = true
    property = "mode"
  }
  legend_options_fields {
    enabled  = true
    property = "host.name"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.platform"
  }
  legend_options_fields {
    enabled  = true
    property = "host.id"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.region"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.provider"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.node.name"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.account.id"
  }
  legend_options_fields {
    enabled  = true
    property = "device"
  }
  legend_options_fields {
    enabled  = true
    property = "deployment.environment"
  }
  legend_options_fields {
    enabled  = true
    property = "state"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.resourcegroup.name"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.vm.name"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.vm.size"
  }
  legend_options_fields {
    enabled  = true
    property = "azure_resource_id"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.vm.scaleset.name"
  }
  legend_options_fields {
    enabled  = true
    property = "gcp_id"
  }

  viz_options {
    axis         = "left"
    display_name = "Disk utilization"
    label        = "D"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    display_name = "Free disk"
    label        = "C"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    display_name = "Used disk"
    label        = "B"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "P50"
    label        = "G"
  }
  viz_options {
    axis         = "left"
    color        = "chartreuse"
    display_name = "Min"
    label        = "E"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "P90"
    label        = "H"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Max"
    label        = "I"
  }
  viz_options {
    axis         = "left"
    color        = "yellowgreen"
    display_name = "P10"
    label        = "F"
  }
}

resource "signalfx_list_chart" "chart_disk_metrics_24h_change" {
  name        = "Disk metrics 24h change (%)"
  description = "Change over 24h"

  program_text = <<-EOF
A = data('^aws.ec2.disk.ops.read.total').sum().mean(over='1h').scale(60).publish(label='A', enable=False)
B = (A).timeshift('1d').publish(label='B', enable=False)
C = (A/B-1).scale(100).publish(label='C')
D = data('^aws.ec2.disk.ops.write.total').sum().mean(over='1h').scale(60).publish(label='D', enable=False)
E = (D).timeshift('1d').publish(label='E', enable=False)
F = (D/E-1).scale(100).publish(label='F')
G = data('^aws.ec2.disk.io.read.total').sum().mean(over='1h').scale(60).publish(label='G', enable=False)
H = (G).timeshift('1d').publish(label='H', enable=False)
I = (G/H-1).scale(100).publish(label='I')
J = data('^aws.ec2.disk.io.write.total').sum().mean(over='1h').scale(60).publish(label='J', enable=False)
K = (J).timeshift('1d').publish(label='K', enable=False)
L = (J/K-1).scale(100).publish(label='L')
EOF

  sort_by = "-value"

  color_by                = "Scale"
  unit_prefix             = "Binary"
  max_precision           = 4
  secondary_visualization = "Sparkline"
  time_range              = 900
  refresh_interval        = 60

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "AWSUniqueId"
  }

  viz_options {
    display_name = "A - timeshift 1d"
    label        = "B"
  }
  viz_options {
    display_name = "D - timeshift 1d"
    label        = "E"
  }
  viz_options {
    display_name = "Disk I/O read"
    label        = "I"
    value_suffix = "%"
  }
  viz_options {
    display_name = "Disk I/O write"
    label        = "L"
    value_suffix = "%"
  }
  viz_options {
    display_name = "Disk ops read"
    label        = "C"
    value_suffix = "%"
  }
  viz_options {
    display_name = "Disk ops write"
    label        = "F"
    value_suffix = "%"
  }
  viz_options {
    display_name = "G - timeshift 1d"
    label        = "H"
  }
  viz_options {
    display_name = "J - timeshift 1d"
    label        = "K"
  }
  viz_options {
    display_name = "^aws.ec2.disk.io.read.total - sum - mean(1h) - scale:60"
    label        = "G"
  }
  viz_options {
    display_name = "^aws.ec2.disk.io.write.total - sum - mean(1h) - scale:60"
    label        = "J"
  }
  viz_options {
    display_name = "^aws.ec2.disk.ops.read.total - sum - mean(1h) - scale:60"
    label        = "A"
  }
  viz_options {
    display_name = "^aws.ec2.disk.ops.write.total - sum - mean(1h) - scale:60"
    label        = "D"
  }
}

resource "signalfx_list_chart" "chart_top_images_by_mean_cpu_utilization" {
  name        = "Top images by mean CPU utilization (%)"
  description = "By aws_image_id"

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=5).mean(by=['aws_image_id']).top(count=5).publish(label='A',enable=False)
B = data('cpu.utilization', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), extrapolation='last_value', maxExtrapolations=5).dimensions(renames={'aws_image_id':'host.image.id'}).mean(by=['aws_image_id']).top(count=5).publish(label='B',enable=False)
C = union(A,B).top(count=5).publish("C")
EOF

  sort_by = "-value"

  color_by                = "Scale"
  time_range              = 900
  refresh_interval        = 60
  max_precision           = 4
  secondary_visualization = "None"

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_image_id"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "CPU utilization - OTel"
    label        = "B"
  }
  viz_options {
    display_name = "CPU utilization - cloudWatch"
    label        = "A"
    value_suffix = "%"
  }
  viz_options {
    display_name = "Union"
    label        = "C"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "chart_network_in_bytes" {
  name        = "Network in (bytes)"
  description = "Percentile distribution across all active hosts"

  program_text = <<-EOF
A = data('^aws.ec2.network.io.receive.total', extrapolation='last_value', maxExtrapolations=5).publish(label='A', enable=False)
B = (A).min().publish(label='B')
C = (A).percentile(pct=10).publish(label='C')
D = (A).percentile(pct=50).publish(label='D')
E = (A).percentile(pct=90).publish(label='E')
F = (A).max().publish(label='F')
EOF

  plot_type = "AreaChart"

  axes_precision            = 0
  unit_prefix               = "Binary"
  on_chart_legend_dimension = "plot_label"

  time_range = 3600

  axis_left {
    min_value = 0
    label     = "Bytes"
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    display_name = "Network bytes in"
    label        = "A"
  }
  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "Median"
    label        = "D"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "chartreuse"
    display_name = "Min"
    label        = "B"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "P90"
    label        = "E"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Max"
    label        = "F"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "left"
    color        = "yellowgreen"
    display_name = "P10"
    label        = "C"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "chart_memory_utilization" {
  name        = "Memory utilization (%)"
  description = "Percentile distribution across active hosts with agent installed"

  program_text = <<-EOF
H = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used')).sum(by=['host.name']).publish(label='H', enable=False)
I = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used', 'free', 'cached', 'buffered')).sum(by=['host.name']).publish(label='I', enable=False)
J = ((H/I)*100).publish(label='J', enable=False)
C = (J).min().publish(label='C')
D = (J).percentile(pct=10).publish(label='D')
E = (J).percentile(pct=50).publish(label='E')
F = (J).percentile(pct=90).publish(label='F')
G = (J).max().publish(label='G')
A = alerts(autodetect_id='F7vC_VlAYAI', filter=filter('aws_tag_ProductFamilyName', 'Forge MT')).publish(label='A')
EOF

  plot_type = "AreaChart"

  axes_precision = 0

  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  axis_left {
    max_value = 120
    min_value = 0
  }

  event_options {
    display_name = "Autodetect alerts"
    label        = "A"
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.region"
  }
  legend_options_fields {
    enabled  = true
    property = "host.image.id"
  }
  legend_options_fields {
    enabled  = true
    property = "os.type"
  }
  legend_options_fields {
    enabled  = true
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "host.type"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.availability_zone"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.provider"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.account.id"
  }
  legend_options_fields {
    enabled  = true
    property = "host.name"
  }
  legend_options_fields {
    enabled  = true
    property = "state"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.platform"
  }
  legend_options_fields {
    enabled  = true
    property = "host.id"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
  legend_options_fields {
    enabled  = true
    property = "deployment.environment"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.node.name"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.resourcegroup.name"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.vm.name"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.vm.size"
  }
  legend_options_fields {
    enabled  = true
    property = "azure_resource_id"
  }
  legend_options_fields {
    enabled  = true
    property = "azure.vm.scaleset.name"
  }
  legend_options_fields {
    enabled  = true
    property = "gcp_id"
  }
  legend_options_fields {
    enabled  = true
    property = "telemetry.sdk.name"
  }
  legend_options_fields {
    enabled  = true
    property = "telemetry.sdk.language"
  }
  legend_options_fields {
    enabled  = true
    property = "telemetry.sdk.version"
  }
  legend_options_fields {
    enabled  = true
    property = "service.name"
  }

  viz_options {
    axis         = "left"
    display_name = "Memory total"
    label        = "I"
  }
  viz_options {
    axis         = "left"
    display_name = "Memory usage"
    label        = "H"
  }
  viz_options {
    axis         = "left"
    display_name = "Memory utilization"
    label        = "J"
  }
  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "Median"
    label        = "E"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    color        = "chartreuse"
    display_name = "Min"
    label        = "C"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "P90"
    label        = "F"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Max"
    label        = "G"
    value_suffix = "%"
  }
  viz_options {
    axis         = "left"
    color        = "yellowgreen"
    display_name = "P10"
    label        = "D"
    value_suffix = "%"
  }
}

resource "signalfx_time_chart" "chart_disk_io_bytes" {
  name = "Disk I/O (bytes)"

  program_text = <<-EOF
A = data('^aws.ec2.disk.io.write.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='A')
B = data('^aws.ec2.disk.io.read.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='B')
EOF

  plot_type = "ColumnChart"

  axes_precision            = 0
  unit_prefix               = "Binary"
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  axis_left {
    min_value = 0
  }
  axis_right {
    min_value = 0
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "Bytes written"
    label        = "A"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "right"
    color        = "orange"
    display_name = "Bytes read"
    label        = "B"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "chart_network_in_bytes_vs_24h_change" {
  name = "Network in (bytes) vs. 24h change (%)"

  program_text = <<-EOF
C = (B).timeshift('1d').publish(label='C', enable=False)
A = data('^aws.ec2.network.io.receive.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='A')
B = (A).mean(over='1h').publish(label='B', enable=False)
D = (B/C-1).scale(100).publish(label='D')
EOF

  plot_type = "ColumnChart"

  axes_precision = 0
  unit_prefix    = "Binary"

  on_chart_legend_dimension = "plot_label"

  time_range = 3600

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    display_name = "A - mean(1h)"
    label        = "B"
  }
  viz_options {
    axis         = "left"
    color        = "blue"
    display_name = "Network in"
    label        = "A"
    value_unit   = "Byte"
  }
  viz_options {
    axis         = "right"
    color        = "orange"
    display_name = "24h change (%)"
    label        = "D"
    plot_type    = "LineChart"
  }
  viz_options {
    axis         = "right"
    color        = "yellow"
    display_name = "C"
    label        = "C"
    plot_type    = "LineChart"
  }
}

resource "signalfx_list_chart" "chart_total_network_errors" {
  name = "# Total network errors"

  program_text = <<-EOF
A = data('system.network.errors', filter=filter('direction', 'receive') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).count().publish(label='A')
B = data('system.network.errors', filter=filter('direction', 'transmit') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).count().publish(label='B')
EOF

  sort_by = "-value"

  color_by         = "Metric"
  max_precision    = 4
  refresh_interval = 60
  time_range       = 900

  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    color        = "blue"
    display_name = "Errors with bytes in"
    label        = "A"
  }
  viz_options {
    color        = "orange"
    display_name = "Errors with bytes out"
    label        = "B"
  }
}

resource "signalfx_list_chart" "chart_top_memory_page_swaps_sec" {
  name        = "Top memory page swaps/sec"
  description = "From hosts with agent installed"

  program_text = <<-EOF
A = data('vmpage_io.swap.in', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks')).mean(by=['host.name']).top(count=5).publish(label='A')
B = data('vmpage_io.swap.out', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), rollup='rate').mean(by=['host.name']).top(count=5).publish(label='B')
EOF

  sort_by = "-value"

  color_by         = "Scale"
  max_precision    = 4
  time_range       = 900
  refresh_interval = 60

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "host.name"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "Pages swapped in"
    label        = "A"
  }
  viz_options {
    display_name = "Pages swapped out"
    label        = "B"
  }
}

resource "signalfx_list_chart" "chart_active_hosts_per_instance_type" {
  name        = "# Active hosts per instance type"
  description = "That reported in the last hour"

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=5).max(over='1h').count(by=['aws_instance_type']).publish(label='A',enable=False)
A.publish("C")
EOF

  sort_by = "-value"

  color_by                = "Scale"
  max_precision           = 0
  secondary_visualization = "Sparkline"
  time_range              = 900

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_instance_type"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "CPU utilization - cloudWatch"
    label        = "A"
  }
  viz_options {
    display_name = "Union"
    label        = "C"
  }
}

resource "signalfx_time_chart" "chart_cpu_utilization" {
  name        = "CPU utilization (%)"
  description = "Percentile distribution across all active hosts"

  program_text = <<-EOF
AB = alerts(autodetect_id='F7vDCq0AgAE', filter=filter('aws_tag_ProductFamilyName', 'Forge MT')).publish(label='Autodetect alerts')
A = data('^aws.ec2.cpu.utilization', extrapolation='last_value', maxExtrapolations=5).publish(label='A', enable=False)
B = (A).min().publish(label='B')
C = (A).percentile(pct=10).publish(label='C')
D = (A).percentile(pct=50).publish(label='D')
E = (A).percentile(pct=90).publish(label='E')
F = (A).max().publish(label='F')
EOF

  plot_type = "AreaChart"

  axes_precision            = 0
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  axis_left {
    max_value = 110
  }

  event_options {
    display_name = "Autodetect alerts"
    label        = "Autodetect alerts"
  }

  histogram_options {
    color_theme = "gold"
  }

  legend_options_fields {
    enabled  = true
    property = "sf_metric"
  }

  viz_options {
    axis         = "left"
    display_name = "CPU utilization"
    label        = "A"
  }
  viz_options {
    axis         = "left"
    color        = "azure"
    display_name = "Median"
    label        = "D"
  }
  viz_options {
    axis         = "left"
    color        = "chartreuse"
    display_name = "Min"
    label        = "B"
  }
  viz_options {
    axis         = "left"
    color        = "pink"
    display_name = "P90"
    label        = "E"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Max"
    label        = "F"
  }
  viz_options {
    axis         = "left"
    color        = "yellowgreen"
    display_name = "P10"
    label        = "C"
  }
}

resource "signalfx_list_chart" "chart_active_hosts_by_availability_zone" {
  name        = "# Active hosts by availability zone"
  description = "That reported in the last hour"

  program_text = <<-EOF
A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=5).max(over='1h').count(by=['aws_availability_zone']).publish(label='A',enable=False)
B = data('cpu.utilization', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), extrapolation='last_value', maxExtrapolations=5).dimensions(renames={'aws_availability_zone':'cloud.availability_zone'}).max(over='1h').count(by=['aws_availability_zone']).publish(label='B',enable=False)
C = union(A,B).publish("C")
EOF

  sort_by = "-value"

  color_by                = "Scale"
  time_range              = 900
  secondary_visualization = "None"

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "aws_availability_zone"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }

  viz_options {
    display_name = "CPU utilization - OTel"
    label        = "B"
  }
  viz_options {
    display_name = "CPU utilization - cloudWatch"
    label        = "A"
  }
  viz_options {
    display_name = "Union"
    label        = "C"
  }
}

resource "signalfx_list_chart" "chart_disk_summary_utilization" {
  name        = "Disk summary utilization (%)"
  description = "Percent of disk space utilized on all volumes on active hosts with agent installed. Instance id | Host"

  program_text = <<-EOF
A = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used')).publish(label='A', enable=False)
B = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'free')).publish(label='B', enable=False)
C = ((A/(A+B))*100).mean(by=['host.name', 'AWSUniqueId']).publish(label='C')
EOF

  sort_by = "-value"

  max_precision = 4
  time_range    = 3600


  legend_options_fields {
    enabled  = false
    property = "sf_originatingMetric"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = true
    property = "aws_instance_id"
  }
  legend_options_fields {
    enabled  = true
    property = "host.name"
  }
  legend_options_fields {
    enabled  = true
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = true
    property = "host.image.id"
  }
  legend_options_fields {
    enabled  = true
    property = "os.type"
  }
  legend_options_fields {
    enabled  = true
    property = "type"
  }
  legend_options_fields {
    enabled  = true
    property = "host.type"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.availability_zone"
  }
  legend_options_fields {
    enabled  = true
    property = "mountpoint"
  }
  legend_options_fields {
    enabled  = true
    property = "mode"
  }
  legend_options_fields {
    enabled  = true
    property = "state"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.platform"
  }
  legend_options_fields {
    enabled  = true
    property = "host.id"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.region"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.provider"
  }
  legend_options_fields {
    enabled  = true
    property = "cloud.account.id"
  }
  legend_options_fields {
    enabled  = true
    property = "device"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.cluster.name"
  }
  legend_options_fields {
    enabled  = true
    property = "k8s.node.name"
  }
  legend_options_fields {
    enabled  = true
    property = "deployment.environment"
  }

  viz_options {
    display_name = "Disk free"
    label        = "B"
    value_suffix = "%"
  }
  viz_options {
    display_name = "Disk summary urilzation"
    label        = "C"
    value_suffix = "%"
  }
  viz_options {
    display_name = "Disk used"
    label        = "A"
    value_suffix = "%"
  }
}

resource "signalfx_single_value_chart" "chart_hosts_with_agent_installed" {
  name        = "# Hosts with agent installed"
  description = "Splunk OTel connector installed"

  program_text = "A = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), rollup='average').sum(by=['AWSUniqueId']).count().publish(label='A')"

  color_by         = "Dimension"
  max_precision    = 4
  refresh_interval = 60

  viz_options {
    display_name = "Hosts with agent installed"
    label        = "A"
  }
}

resource "signalfx_list_chart" "chart_top_5_network_out_bytes" {
  name        = "Top 5 network out (bytes)"
  description = "By AWSUniqueId"

  program_text = "A = data('^aws.ec2.network.io.transmit.total', extrapolation='last_value', maxExtrapolations=5).mean(by=['AWSUniqueId']).top(count=5).publish(label='A')"

  sort_by = "-value"

  color_by                = "Scale"
  unit_prefix             = "Binary"
  time_range              = 900
  max_precision           = 4
  refresh_interval        = 60
  secondary_visualization = "None"

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_instance_id"
  }

  viz_options {
    display_name = "Network out"
    label        = "A"
    value_unit   = "Byte"
  }
}

resource "signalfx_single_value_chart" "chart_active_hosts" {
  name = "# Active hosts"

  program_text = "A = data('^aws.ec2.cpu.utilization', extrapolation='last_value', maxExtrapolations=2).sum(by=['AWSUniqueId']).count().publish(label='A')"

  color_by         = "Dimension"
  max_precision    = 4
  refresh_interval = 60

  viz_options {
    display_name = "# Hosts"
    label        = "A"
  }
}

resource "signalfx_list_chart" "chart_top_5_network_in_bytes" {
  name        = "Top 5 network in (bytes)"
  description = "By AWSUniqueId"

  program_text = "A = data('^aws.ec2.network.io.receive.total', extrapolation='last_value', maxExtrapolations=5).mean(by=['AWSUniqueId']).top(count=5).publish(label='A')"

  sort_by = "-value"

  color_by                = "Scale"
  unit_prefix             = "Binary"
  max_precision           = 4
  refresh_interval        = 60
  time_range              = 900
  secondary_visualization = "None"

  color_scale {
    color = "blue"
    gt    = 0
  }
  color_scale {
    color = "red"
    lte   = 0
  }

  legend_options_fields {
    enabled  = true
    property = "AWSUniqueId"
  }
  legend_options_fields {
    enabled  = false
    property = "sf_metric"
  }
  legend_options_fields {
    enabled  = false
    property = "aws_instance_id"
  }

  viz_options {
    display_name = "Network in"
    label        = "A"
    value_unit   = "Byte"
  }
}


########################
# DASHBOARD
########################

resource "signalfx_dashboard" "runner_ec2" {
  name            = "EC2 Runners"
  description     = ""
  dashboard_group = signalfx_dashboard_group.forgecicd.id

  variable {
    property               = "aws_tag_TenantName"
    alias                  = "ForgeCICD Tenant Name"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = var.dashboard_variables.runner_ec2.tenant_names
    restricted_suggestions = true
  }

  variable {
    property               = "aws_instance_id"
    alias                  = "ForgeCICD Instance ID"
    description            = ""
    values                 = []
    value_required         = false
    values_suggested       = []
    restricted_suggestions = false
  }

  dynamic "variable" {
    for_each = var.dashboard_variables.runner_ec2.dynamic_variables
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
    chart_id = signalfx_single_value_chart.chart_active_hosts.id
    row      = 0
    column   = 0
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_single_value_chart.chart_hosts_with_agent_installed.id
    row      = 0
    column   = 3
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_active_hosts_per_instance_type.id
    row      = 0
    column   = 9
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_active_hosts_by_availability_zone.id
    row      = 0
    column   = 6
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_cpu_utilization.id
    row      = 1
    column   = 0
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_top_instances_by_cpu_utilization.id
    row      = 1
    column   = 4
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_top_images_by_mean_cpu_utilization.id
    row      = 1
    column   = 8
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_total_memory_overview_bytes.id
    row      = 2
    column   = 4
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_top_memory_page_swaps_sec.id
    row      = 2
    column   = 8
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_memory_utilization.id
    row      = 2
    column   = 0
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_disk_metrics_24h_change.id
    row      = 3
    column   = 9
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_disk_io_bytes.id
    row      = 3
    column   = 6
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_disk_utilization.id
    row      = 3
    column   = 0
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_disk_ops.id
    row      = 3
    column   = 3
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_top_5_network_in_bytes.id
    row      = 4
    column   = 6
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_network_in_bytes_vs_24h_change.id
    row      = 4
    column   = 9
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_disk_summary_utilization.id
    row      = 4
    column   = 0
    width    = 6
    height   = 2
  }
  chart {
    chart_id = signalfx_list_chart.chart_top_5_network_out_bytes.id
    row      = 5
    column   = 6
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_network_out_bytes_vs_24h_change.id
    row      = 5
    column   = 9
    width    = 3
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_network_out_bytes.id
    row      = 6
    column   = 8
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.chart_network_in_bytes.id
    row      = 6
    column   = 0
    width    = 4
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.chart_total_network_errors.id
    row      = 6
    column   = 4
    width    = 4
    height   = 1
  }

}
