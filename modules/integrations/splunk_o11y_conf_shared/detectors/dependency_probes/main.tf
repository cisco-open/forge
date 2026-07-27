locals {
  detector_tags                 = ["forgecicd", "tenant-health", "dependency-probe", "terraform"]
  build_queue_filter            = "filter('QueueName', '*-queued-builds') and (not filter('QueueName', '*dead-letter*', '*dead_letter*', '*dlq*', '*DLQ*'))"
  dead_letter_queue_name_filter = "filter('QueueName', '*dead-letter*', '*dead_letter*', '*dlq*', '*DLQ*')"
}

resource "signalfx_detector" "tenant_dependency_health" {
  for_each = toset(var.tenant_names)

  name        = "${var.detector_name_prefix} tenant ${each.value} health"
  description = "Monitors ${each.value} dependencies, Lambda failures, build queues, Kubernetes workloads, EC2 status and resource pressure, and EBS IOPS limits."
  max_delay   = 120
  tags        = local.detector_tags
  teams       = [var.team]
  time_range  = 3600

  program_text = <<-EOF
tenant_cycle = data('forge.dependency.probe_executed', filter=filter('TenantName', '${each.value}') and filter('Provider', 'Forge') and filter('CheckName', 'TenantCycle'), rollup='latest').max(by=['AWSRegion']).fill(value=0, duration='${var.detector_config.no_data_fill_duration}')
ssm_availability = data('forge.dependency.availability', filter=filter('TenantName', '${each.value}') and filter('Provider', 'AWS') and filter('CheckName', 'SSMCredentials'), rollup='min').min(by=['AWSRegion']).fill(value=0, duration='${var.detector_config.no_data_fill_duration}')
github_availability = data('forge.dependency.availability', filter=filter('TenantName', '${each.value}') and filter('Provider', 'GitHub'), rollup='min').min(by=['AWSRegion']).fill(value=0, duration='${var.detector_config.no_data_fill_duration}')
github_rate_limit_remaining_pct = data('forge.dependency.rate_limit_remaining_pct', filter=filter('TenantName', '${each.value}') and filter('Provider', 'GitHub') and filter('CheckName', 'OrgRunnersApi'), rollup='min').min(by=['AWSRegion']).fill(value=100, duration='${var.detector_config.no_data_fill_duration}')
lambda_errors = data('Errors', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(over='10m').sum(by=['aws_region', 'aws_function_name', 'aws_tag_ForgeModuleRef'])
lambda_invocations = data('Invocations', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(over='10m').sum(by=['aws_region', 'aws_function_name', 'aws_tag_ForgeModuleRef'])
lambda_error_rate = (lambda_errors / lambda_invocations) * 100
lambda_throttles = data('Throttles', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/Lambda') and filter('stat', 'sum') and filter('aws_tag_ForgeModuleRef', '*'), rollup='sum', extrapolation='zero').sum(over='5m').sum(by=['aws_region', 'aws_function_name', 'aws_tag_ForgeModuleRef'])
build_queue_oldest_age = data('ApproximateAgeOfOldestMessage', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.build_queue_filter}), rollup='latest').max(over='5m').max(by=['aws_region', 'QueueName'])
build_queue_visible_messages = data('ApproximateNumberOfMessagesVisible', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.build_queue_filter}), rollup='latest').max(over='5m').max(by=['aws_region', 'QueueName'])
dlq_visible_messages = data('ApproximateNumberOfMessagesVisible', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/SQS') and filter('stat', 'upper') and (${local.dead_letter_queue_name_filter}), rollup='latest').max(over='5m').max(by=['aws_region', 'QueueName'])
pending_pods = data('k8s.pod.phase', filter=filter('k8s.namespace.name', '${each.value}'), rollup='latest').between(0, 1.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name']).fill(value=0, duration='10m')
failed_or_unknown_pods = data('k8s.pod.phase', filter=filter('k8s.namespace.name', '${each.value}'), rollup='latest').between(3.5, 5.5, low_inclusive=True, high_inclusive=True).sum(by=['k8s.cluster.name']).fill(value=0, duration='10m')
container_restarts = data('k8s.container.restarts', filter=filter('k8s.namespace.name', '${each.value}') and filter('k8s.container.name', '*'), rollup='latest').max(by=['k8s.cluster.name', 'k8s.pod.name', 'k8s.container.name']).delta().sum(over='15m').sum(by=['k8s.cluster.name']).fill(value=0, duration='15m')
ec2_status_failures = data('StatusCheckFailed', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/EC2') and filter('stat', 'upper') and filter('aws_instance_id', '*'), rollup='max', extrapolation='zero').max(over='5m').max(by=['aws_region', 'aws_instance_id'])
ec2_disk_used = data('system.filesystem.usage', filter=filter('aws_tag_TenantName', '${each.value}') and filter('cloud.platform', 'aws_ec2') and filter('state', 'used') and filter('type', 'ext4', 'xfs'), rollup='average').sum(by=['host.name', 'mountpoint', 'type', 'aws_account_id', 'aws_region'])
ec2_disk_total = data('system.filesystem.usage', filter=filter('aws_tag_TenantName', '${each.value}') and filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free') and filter('type', 'ext4', 'xfs'), rollup='average').sum(by=['host.name', 'mountpoint', 'type', 'aws_account_id', 'aws_region'])
ec2_disk_utilization = ((ec2_disk_used / ec2_disk_total) * 100).mean(over='5m')
ec2_memory_used = data('system.memory.usage', filter=filter('aws_tag_TenantName', '${each.value}') and filter('cloud.platform', 'aws_ec2') and filter('state', 'used'), rollup='average').sum(by=['host.name', 'aws_account_id', 'aws_region'])
ec2_memory_total = data('system.memory.usage', filter=filter('aws_tag_TenantName', '${each.value}') and filter('cloud.platform', 'aws_ec2') and filter('state', 'used', 'free', 'cached', 'buffered'), rollup='average').sum(by=['host.name', 'aws_account_id', 'aws_region'])
ec2_memory_utilization = ((ec2_memory_used / ec2_memory_total) * 100).mean(over='5m')
ebs_iops_exceeded = data('VolumeIOPSExceededCheck', filter=filter('aws_tag_TenantName', '${each.value}') and filter('namespace', 'AWS/EBS') and filter('stat', 'upper') and filter('VolumeId', '*'), rollup='latest', extrapolation='zero').max(over='5m').max(by=['aws_region', 'VolumeId'])
detect(when(tenant_cycle < 1, '${var.detector_config.no_data_duration}')).publish('Tenant dependency probe has no data')
detect(when(ssm_availability < 1, '${var.detector_config.failure_duration}')).publish('Tenant GitHub App SSM credentials unavailable')
detect(when(github_availability < 1, '${var.detector_config.failure_duration}')).publish('Tenant GitHub API unavailable')
detect(when(github_rate_limit_remaining_pct < ${var.detector_config.rate_limit_remaining_pct_threshold}, '${var.detector_config.rate_limit_duration}')).publish('Tenant GitHub API rate-limit budget low')
detect(when((lambda_errors >= 3) and (lambda_error_rate >= 5), '10m')).publish('Tenant Lambda error rate high')
detect(when(lambda_throttles > 0, '5m')).publish('Tenant Lambda throttling')
detect(when((build_queue_oldest_age > 75) and (build_queue_visible_messages > 10), '10m'), off=when(build_queue_oldest_age < 60, '15m')).publish('Tenant build queue delayed')
detect(when(build_queue_oldest_age > 300, '10m'), off=when(build_queue_oldest_age < 60, '15m')).publish('Tenant build queue stuck')
detect(when(dlq_visible_messages > 0, '5m')).publish('Tenant DLQ backlog')
detect(when(pending_pods > 0, '10m')).publish('Tenant Kubernetes pod pending')
detect(when(failed_or_unknown_pods > 0, '10m')).publish('Tenant Kubernetes pod failed or unknown')
detect(when(container_restarts > 3)).publish('Tenant Kubernetes container restarting')
detect(when(ec2_status_failures > 0, '5m')).publish('Tenant EC2 status check failure')
detect(when(ec2_disk_utilization > 80, '10m'), off=when(ec2_disk_utilization < 75, '10m'), auto_resolve_after='15m').publish('Tenant EC2 disk pressure')
detect(when(ec2_memory_utilization > 90, '10m'), off=when(ec2_memory_utilization < 80, '10m'), auto_resolve_after='15m').publish('Tenant EC2 memory pressure')
detect(when(ebs_iops_exceeded > 0, '5m')).publish('Tenant EBS IOPS limit exceeded')
EOF

  rule {
    description   = "Dependency probe telemetry missing for ${var.detector_config.no_data_duration}"
    severity      = "Warning"
    detect_label  = "Tenant dependency probe has no data"
    notifications = var.detector_notifications
  }

  rule {
    description   = "GitHub App SSM credentials unavailable for ${var.detector_config.failure_duration}"
    severity      = "Major"
    detect_label  = "Tenant GitHub App SSM credentials unavailable"
    notifications = var.detector_notifications
  }

  rule {
    description   = "GitHub authentication or organization runner API unavailable for ${var.detector_config.failure_duration}"
    severity      = "Major"
    detect_label  = "Tenant GitHub API unavailable"
    notifications = var.detector_notifications
  }

  rule {
    description   = "GitHub API rate-limit budget below ${var.detector_config.rate_limit_remaining_pct_threshold}% for ${var.detector_config.rate_limit_duration}"
    severity      = "Warning"
    detect_label  = "Tenant GitHub API rate-limit budget low"
    notifications = var.detector_notifications
  }

  rule {
    description   = "At least 3 Lambda errors and at least 5 percent error rate for 10 minutes, grouped by function"
    severity      = "Major"
    detect_label  = "Tenant Lambda error rate high"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Lambda throttling sustained for 5 minutes, grouped by function"
    severity      = "Major"
    detect_label  = "Tenant Lambda throttling"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Build queue oldest-message age above 75 seconds and visible backlog above 10 for 10 minutes"
    severity      = "Warning"
    detect_label  = "Tenant build queue delayed"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Build queue oldest-message age above 300 seconds for 10 minutes"
    severity      = "Major"
    detect_label  = "Tenant build queue stuck"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Visible messages present in a dead-letter queue for 5 minutes"
    severity      = "Major"
    detect_label  = "Tenant DLQ backlog"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Kubernetes pod pending for 10 minutes, grouped by cluster"
    severity      = "Warning"
    detect_label  = "Tenant Kubernetes pod pending"
    notifications = var.detector_notifications
  }

  rule {
    description   = "Kubernetes pod failed or unknown for 10 minutes, grouped by cluster"
    severity      = "Major"
    detect_label  = "Tenant Kubernetes pod failed or unknown"
    notifications = var.detector_notifications
  }

  rule {
    description   = "More than 3 Kubernetes container restarts in 15 minutes, grouped by cluster"
    severity      = "Warning"
    detect_label  = "Tenant Kubernetes container restarting"
    notifications = var.detector_notifications
  }

  rule {
    description   = "EC2 instance status-check failure sustained for 5 minutes"
    severity      = "Major"
    detect_label  = "Tenant EC2 status check failure"
    notifications = var.detector_notifications
  }

  rule {
    description   = "EC2 writable filesystem utilization above 80 percent for 10 minutes"
    severity      = "Major"
    detect_label  = "Tenant EC2 disk pressure"
    notifications = var.detector_notifications
  }

  rule {
    description   = "EC2 memory utilization above 90 percent for 10 minutes"
    severity      = "Major"
    detect_label  = "Tenant EC2 memory pressure"
    notifications = var.detector_notifications
  }

  rule {
    description   = "EBS provisioned-IOPS exceeded check sustained for 5 minutes"
    severity      = "Warning"
    detect_label  = "Tenant EBS IOPS limit exceeded"
    notifications = var.detector_notifications
  }
}
