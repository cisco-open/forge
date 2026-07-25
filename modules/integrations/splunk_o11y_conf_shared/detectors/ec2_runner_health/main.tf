locals {
  detector_tags = ["forgecicd", "aws", "ec2-runner", "terraform"]

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
  tenant_filter = length(var.tenant_names) > 0 ? join(" or ", [
    for tenant_name in sort(var.tenant_names) : "filter('aws_tag_TenantName', '${tenant_name}')"
  ]) : "filter('aws_tag_TenantName', '__forge_tenant_scope_not_configured__')"

  runner_filter = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter}) and (${local.tenant_filter})"
}

resource "signalfx_detector" "ec2_runner_cpu" {
  name        = "${var.detector_name_prefix} EC2 runner high CPU"
  description = "Detects sustained high CPU on active Forge EC2 runners and automatically resolves incidents after terminated runners stop reporting."
  max_delay   = 120
  tags        = concat(local.detector_tags, ["cpu"])
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
cpu = data('^aws.ec2.cpu.utilization', filter=(${local.runner_filter}), extrapolation='last_value', maxExtrapolations=3).mean(over='5m').mean(by=['aws_account_id', 'aws_region', 'aws_instance_id', 'aws_tag_TenantName'])
detect(when(cpu > 90, '10m'), off=when(cpu < 70, '10m'), auto_resolve_after='15m').publish('Forge EC2 runner high CPU')
EOF

  rule {
    description   = "Forge EC2 runner CPU above 90 percent for 10 minutes"
    severity      = "Major"
    detect_label  = "Forge EC2 runner high CPU"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "ec2_runner_disk" {
  name        = "${var.detector_name_prefix} EC2 runner high disk utilization"
  description = "Detects sustained high utilization on writable Forge EC2 runner filesystems and excludes read-only squashfs mounts."
  max_delay   = 120
  tags        = concat(local.detector_tags, ["disk"])
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
used = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and filter('type', 'ext4', 'xfs') and (${local.runner_filter}), rollup='average').sum(by=['host.name', 'mountpoint', 'type', 'aws_account_id', 'aws_region', 'aws_tag_TenantName'])
total = data('system.filesystem.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free') and filter('type', 'ext4', 'xfs') and (${local.runner_filter}), rollup='average').sum(by=['host.name', 'mountpoint', 'type', 'aws_account_id', 'aws_region', 'aws_tag_TenantName'])
disk = ((used / total) * 100).mean(over='5m')
detect(when(disk > 80, '10m'), off=when(disk < 75, '10m'), auto_resolve_after='15m').publish('Forge EC2 runner high disk utilization')
EOF

  rule {
    description   = "Forge EC2 runner writable filesystem above 80 percent for 10 minutes"
    severity      = "Major"
    detect_label  = "Forge EC2 runner high disk utilization"
    notifications = var.detector_notifications
  }
}

resource "signalfx_detector" "ec2_runner_memory" {
  name        = "${var.detector_name_prefix} EC2 runner high memory utilization"
  description = "Detects sustained high memory utilization on active Forge EC2 runners and automatically resolves incidents after terminated runners stop reporting."
  max_delay   = 120
  tags        = concat(local.detector_tags, ["memory"])
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
used = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and (${local.runner_filter}), rollup='average').sum(by=['host.name', 'aws_account_id', 'aws_region', 'aws_tag_TenantName'])
total = data('system.memory.usage', filter=filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free', 'cached', 'buffered') and (${local.runner_filter}), rollup='average').sum(by=['host.name', 'aws_account_id', 'aws_region', 'aws_tag_TenantName'])
memory = ((used / total) * 100).mean(over='5m')
detect(when(memory > 90, '10m'), off=when(memory < 80, '10m'), auto_resolve_after='15m').publish('Forge EC2 runner high memory utilization')
EOF

  rule {
    description   = "Forge EC2 runner memory above 90 percent for 10 minutes"
    severity      = "Major"
    detect_label  = "Forge EC2 runner high memory utilization"
    notifications = var.detector_notifications
  }
}
