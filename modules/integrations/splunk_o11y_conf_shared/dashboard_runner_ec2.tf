resource "signalfx_time_chart" "chart_disk_ops" {
  name         = "# Disk ops"
  program_text = "A = data('^aws.ec2.disk.ops.write.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='A')\nB = data('^aws.ec2.disk.ops.read.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='B')"
  plot_type    = "ColumnChart"
}

resource "signalfx_time_chart" "chart_total_memory_overview_bytes" {
  name         = "Total memory overview (bytes)"
  description  = "From hosts with agent installed"
  program_text = "C = data('system.memory.usage', filter=filter('state', 'free') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='C')\nF = data('system.memory.usage', filter=filter('state', 'used') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='F')\nA = data('system.memory.usage', filter=filter('state', 'buffered') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='A')\nB = data('system.memory.usage', filter=filter('state', 'cached') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='B')\nD = data('system.memory.usage', filter=filter('state', 'slab_reclaimable') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='D')\nE = data('system.memory.usage', filter=filter('state', 'slab_unreclaimable') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).sum().publish(label='E')"
  plot_type    = "AreaChart"
}

resource "signalfx_time_chart" "chart_network_out_bytes_vs_24h_change" {
  name         = "Network out (bytes) vs. 24h change (%)"
  program_text = "A = data('^aws.ec2.network.io.transmit.total', extrapolation='last_value', maxExtrapolations=5).sum().mean(over='1h').publish(label='A')\nB = (A).timeshift('1d').publish(label='B', enable=False)\nC = (A/B-1).scale(100).publish(label='C')"
  plot_type    = "ColumnChart"
}

resource "signalfx_time_chart" "chart_network_out_bytes" {
  name         = "Network out (bytes)"
  description  = "Percentile distribution across all active hosts"
  program_text = "A = data('^aws.ec2.network.io.transmit.total', extrapolation='last_value', maxExtrapolations=5).publish(label='A', enable=False)\nB = (A).min().publish(label='B')\nC = (A).percentile(pct=10).publish(label='C')\nD = (A).percentile(pct=50).publish(label='D')\nE = (A).percentile(pct=90).publish(label='E')\nF = (A).max().publish(label='F')"
  plot_type    = "AreaChart"
}

resource "signalfx_list_chart" "chart_top_instances_by_cpu_utilization" {
  name         = "Top instances by CPU utilization (%)"
  description  = "By AWSUniqueId"
  program_text = "A = data('^aws.ec2.cpu.utilization', extrapolation='last_value', maxExtrapolations=5).mean(by=['AWSUniqueId']).top(count=5).publish(label='A')"
  sort_by      = "-value"
}

resource "signalfx_time_chart" "chart_disk_utilization" {
  name         = "Disk utilization (%)"
  description  = "Percentile distribution across active hosts with agent installed"
  program_text = "B = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used')).publish(label='B', enable=False)\nC = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'free')).publish(label='C', enable=False)\nD = ((B/(B+C))*100).mean(by=['AWSUniqueId']).publish(label='D', enable=False)\nE = (D).min().publish(label='E')\nF = (D).percentile(pct=10).publish(label='F')\nG = (D).percentile(pct=50).publish(label='G')\nH = (D).percentile(pct=90).publish(label='H')\nI = (D).max().publish(label='I')\nA = alerts(autodetect_id='F6cykK5AYAA', filter=filter('aws_tag_ProductFamilyName', 'Forge MT')).publish(label='A')"
  plot_type    = "AreaChart"
}

resource "signalfx_list_chart" "chart_disk_metrics_24h_change" {
  name         = "Disk metrics 24h change (%)"
  description  = "Change over 24h"
  program_text = "A = data('^aws.ec2.disk.ops.read.total').sum().mean(over='1h').scale(60).publish(label='A', enable=False)\nB = (A).timeshift('1d').publish(label='B', enable=False)\nC = (A/B-1).scale(100).publish(label='C')\nD = data('^aws.ec2.disk.ops.write.total').sum().mean(over='1h').scale(60).publish(label='D', enable=False)\nE = (D).timeshift('1d').publish(label='E', enable=False)\nF = (D/E-1).scale(100).publish(label='F')\nG = data('^aws.ec2.disk.io.read.total').sum().mean(over='1h').scale(60).publish(label='G', enable=False)\nH = (G).timeshift('1d').publish(label='H', enable=False)\nI = (G/H-1).scale(100).publish(label='I')\nJ = data('^aws.ec2.disk.io.write.total').sum().mean(over='1h').scale(60).publish(label='J', enable=False)\nK = (J).timeshift('1d').publish(label='K', enable=False)\nL = (J/K-1).scale(100).publish(label='L')"
  sort_by      = "-value"
}

resource "signalfx_list_chart" "chart_top_images_by_mean_cpu_utilization" {
  name         = "Top images by mean CPU utilization (%)"
  description  = "By aws_image_id"
  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=5).mean(by=['aws_image_id']).top(count=5).publish(label='A',enable=False)\nB = data('cpu.utilization', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), extrapolation='last_value', maxExtrapolations=5).dimensions(renames={'aws_image_id':'host.image.id'}).mean(by=['aws_image_id']).top(count=5).publish(label='B',enable=False)\nC = union(A,B).top(count=5).publish(\"C\")"
  sort_by      = "-value"
}

resource "signalfx_time_chart" "chart_network_in_bytes" {
  name         = "Network in (bytes)"
  description  = "Percentile distribution across all active hosts"
  program_text = "A = data('^aws.ec2.network.io.receive.total', extrapolation='last_value', maxExtrapolations=5).publish(label='A', enable=False)\nB = (A).min().publish(label='B')\nC = (A).percentile(pct=10).publish(label='C')\nD = (A).percentile(pct=50).publish(label='D')\nE = (A).percentile(pct=90).publish(label='E')\nF = (A).max().publish(label='F')"
  plot_type    = "AreaChart"
}

resource "signalfx_time_chart" "chart_memory_utilization" {
  name         = "Memory utilization (%)"
  description  = "Percentile distribution across active hosts with agent installed"
  program_text = "H = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used')).sum(by=['host.name']).publish(label='H', enable=False)\nI = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used', 'free', 'cached', 'buffered')).sum(by=['host.name']).publish(label='I', enable=False)\nJ = ((H/I)*100).publish(label='J', enable=False)\nC = (J).min().publish(label='C')\nD = (J).percentile(pct=10).publish(label='D')\nE = (J).percentile(pct=50).publish(label='E')\nF = (J).percentile(pct=90).publish(label='F')\nG = (J).max().publish(label='G')\nA = alerts(autodetect_id='F7vC_VlAYAI', filter=filter('aws_tag_ProductFamilyName', 'Forge MT')).publish(label='A')"
  plot_type    = "AreaChart"
}

resource "signalfx_time_chart" "chart_disk_io_bytes" {
  name         = "Disk I/O (bytes)"
  program_text = "A = data('^aws.ec2.disk.io.write.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='A')\nB = data('^aws.ec2.disk.io.read.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='B')"
  plot_type    = "ColumnChart"
}

resource "signalfx_time_chart" "chart_network_in_bytes_vs_24h_change" {
  name         = "Network in (bytes) vs. 24h change (%)"
  program_text = "C = (B).timeshift('1d').publish(label='C', enable=False)\nA = data('^aws.ec2.network.io.receive.total', extrapolation='last_value', maxExtrapolations=5).sum().publish(label='A')\nB = (A).mean(over='1h').publish(label='B', enable=False)\nD = (B/C-1).scale(100).publish(label='D')"
  plot_type    = "ColumnChart"
}

resource "signalfx_list_chart" "chart_total_network_errors" {
  name         = "# Total network errors"
  program_text = "A = data('system.network.errors', filter=filter('direction', 'receive') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).count().publish(label='A')\nB = data('system.network.errors', filter=filter('direction', 'transmit') and filter('cloud.platform', 'aws_ec2', 'aws_eks')).count().publish(label='B')"
  sort_by      = "-value"
}

resource "signalfx_list_chart" "chart_top_memory_page_swaps_sec" {
  name         = "Top memory page swaps/sec"
  description  = "From hosts with agent installed"
  program_text = "A = data('vmpage_io.swap.in', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks')).mean(by=['host.name']).top(count=5).publish(label='A')\nB = data('vmpage_io.swap.out', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), rollup='rate').mean(by=['host.name']).top(count=5).publish(label='B')"
  sort_by      = "-value"
}

resource "signalfx_list_chart" "chart_active_hosts_per_instance_type" {
  name         = "# Active hosts per instance type"
  description  = "That reported in the last hour"
  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=5).max(over='1h').count(by=['aws_instance_type']).publish(label='A',enable=False)\nA.publish(\"C\")"
  sort_by      = "-value"
}

resource "signalfx_time_chart" "chart_cpu_utilization" {
  name         = "CPU utilization (%)"
  description  = "Percentile distribution across all active hosts"
  program_text = "AB = alerts(autodetect_id='F7vDCq0AgAE', filter=filter('aws_tag_ProductFamilyName', 'Forge MT')).publish(label='Autodetect alerts')\nA = data('^aws.ec2.cpu.utilization', extrapolation='last_value', maxExtrapolations=5).publish(label='A', enable=False)\nB = (A).min().publish(label='B')\nC = (A).percentile(pct=10).publish(label='C')\nD = (A).percentile(pct=50).publish(label='D')\nE = (A).percentile(pct=90).publish(label='E')\nF = (A).max().publish(label='F')"
  plot_type    = "AreaChart"
}

resource "signalfx_list_chart" "chart_active_hosts_by_availability_zone" {
  name         = "# Active hosts by availability zone"
  description  = "That reported in the last hour"
  program_text = "A = data('CPUUtilization', filter=filter('namespace', 'AWS/EC2') and filter('stat', 'mean'), extrapolation='last_value', maxExtrapolations=5).max(over='1h').count(by=['aws_availability_zone']).publish(label='A',enable=False)\nB = data('cpu.utilization', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), extrapolation='last_value', maxExtrapolations=5).dimensions(renames={'aws_availability_zone':'cloud.availability_zone'}).max(over='1h').count(by=['aws_availability_zone']).publish(label='B',enable=False)\nC = union(A,B).publish(\"C\")"
  sort_by      = "-value"
}

resource "signalfx_list_chart" "chart_disk_summary_utilization" {
  name         = "Disk summary utilization (%)"
  description  = "Percent of disk space utilized on all volumes on active hosts with agent installed. Instance id | Host"
  program_text = "A = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'used')).publish(label='A', enable=False)\nB = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks') and filter('state', 'free')).publish(label='B', enable=False)\nC = ((A/(A+B))*100).mean(by=['host.name', 'AWSUniqueId']).publish(label='C')"
  sort_by      = "-value"
}

resource "signalfx_single_value_chart" "chart_hosts_with_agent_installed" {
  name         = "# Hosts with agent installed"
  description  = "Splunk OTel connector installed"
  program_text = "A = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2', 'aws_eks'), rollup='average').sum(by=['AWSUniqueId']).count().publish(label='A')"
}

resource "signalfx_list_chart" "chart_top_5_network_out_bytes" {
  name         = "Top 5 network out (bytes)"
  description  = "By AWSUniqueId"
  program_text = "A = data('^aws.ec2.network.io.transmit.total', extrapolation='last_value', maxExtrapolations=5).mean(by=['AWSUniqueId']).top(count=5).publish(label='A')"
  sort_by      = "-value"
}

resource "signalfx_single_value_chart" "chart_active_hosts" {
  name         = "# Active hosts"
  program_text = "A = data('^aws.ec2.cpu.utilization', extrapolation='last_value', maxExtrapolations=2).sum(by=['AWSUniqueId']).count().publish(label='A')"
}

resource "signalfx_list_chart" "chart_top_5_network_in_bytes" {
  name         = "Top 5 network in (bytes)"
  description  = "By AWSUniqueId"
  program_text = "A = data('^aws.ec2.network.io.receive.total', extrapolation='last_value', maxExtrapolations=5).mean(by=['AWSUniqueId']).top(count=5).publish(label='A')"
  sort_by      = "-value"
}


########################
# DASHBOARD
########################

resource "signalfx_dashboard" "runner_ec2" {
  name            = "EC2 Runners"
  description     = ""
  dashboard_group = signalfx_dashboard_group.forgecicd.id

  variable {
    property         = "aws_tag_TenantName"
    alias            = "ForgeCICD Tenant Name"
    description      = ""
    values           = []
    value_required   = false
    values_suggested = var.dashboard_variables.runner_ec2.tenant_names
  }

  variable {
    property         = "aws_instance_id"
    alias            = "ForgeCICD Instance ID"
    description      = ""
    values           = []
    value_required   = false
    values_suggested = []
  }

  dynamic "variable" {
    for_each = var.dashboard_variables.runner_ec2.dynamic_variables
    content {
      property         = each.value.property
      alias            = each.value.alias
      description      = each.value.description
      values           = each.value.values
      value_required   = each.value.value_required
      values_suggested = each.value.values_suggested
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
