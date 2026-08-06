mock_provider "signalfx" {
  mock_resource "signalfx_detector" {}
}

variables {
  detector_name_prefix   = "Forge Prod"
  detector_notifications = ["Email,forge@example.com"]
  team                   = "forge-team"
  tenant_names           = ["tenant-b", "tenant-a"]
  dynamic_variables = [
    {
      property               = "aws_account_id"
      alias                  = "AWS account"
      description            = "Forge AWS accounts."
      values                 = []
      value_required         = false
      values_suggested       = ["111111111111"]
      restricted_suggestions = true
    },
    {
      property               = "aws_region"
      alias                  = "AWS region"
      description            = "Forge AWS regions."
      values                 = []
      value_required         = false
      values_suggested       = ["us-east-1", "us-west-2"]
      restricted_suggestions = true
    },
    {
      property               = "aws_tag_ProductFamilyName"
      alias                  = "Product family"
      description            = "Forge AWS product family."
      values                 = []
      value_required         = false
      values_suggested       = ["Forge MT"]
      restricted_suggestions = true
    },
    {
      property               = "aws_tag_Environment"
      alias                  = "Environment"
      description            = "Forge deployment environment."
      values                 = ["prod"]
      value_required         = true
      values_suggested       = ["prod"]
      restricted_suggestions = true
    },
  ]
}

run "creates_scoped_runner_health_detectors" {
  command = plan

  assert {
    condition = (
      signalfx_detector.ec2_runner_cpu.name == "Forge Prod EC2 runner high CPU"
      && signalfx_detector.ec2_runner_disk.name == "Forge Prod EC2 runner high disk utilization"
      && signalfx_detector.ec2_runner_memory.name == "Forge Prod EC2 runner high memory utilization"
      && signalfx_detector.ec2_runner_cpu.teams == toset(["forge-team"])
      && signalfx_detector.ec2_runner_disk.teams == toset(["forge-team"])
      && signalfx_detector.ec2_runner_memory.teams == toset(["forge-team"])
      && length(signalfx_detector.ec2_runner_cpu.rule) == 1
      && length(signalfx_detector.ec2_runner_disk.rule) == 1
      && length(signalfx_detector.ec2_runner_memory.rule) == 1
      && toset(one(signalfx_detector.ec2_runner_cpu.rule).notifications) == toset(["Email,forge@example.com"])
      && length(one(signalfx_detector.ec2_runner_disk.rule).notifications) == 0
      && length(one(signalfx_detector.ec2_runner_memory.rule).notifications) == 0
      && one(signalfx_detector.ec2_runner_cpu.rule).severity == "Major"
      && one(signalfx_detector.ec2_runner_disk.rule).severity == "Major"
      && one(signalfx_detector.ec2_runner_memory.rule).severity == "Major"
    )
    error_message = "The runner health detectors must keep their names, owner team, severity, and explicit notification ownership."
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_detector.ec2_runner_cpu.program_text,
        signalfx_detector.ec2_runner_disk.program_text,
        signalfx_detector.ec2_runner_memory.program_text,
      ] :
      strcontains(program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(program_text, "filter('aws_region', 'us-east-1', 'us-west-2')")
      && strcontains(program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(program_text, "filter('aws_tag_Environment', 'prod')")
      && strcontains(program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
    ])
    error_message = "Every runner health detector must retain all configured dynamic-property and tenant scopes."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.ec2_runner_cpu.program_text, "^aws.ec2.cpu.utilization")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "cpu > 90, '10m'")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "off=when(cpu < 70, '10m')")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "auto_resolve_after='15m'")
    )
    error_message = "Runner CPU SignalFlow must be production-scoped, use stable thresholds, and auto-resolve inactive runner streams."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.ec2_runner_disk.program_text, "system.filesystem.usage")
      && strcontains(signalfx_detector.ec2_runner_disk.program_text, "filter('type', 'ext4', 'xfs')")
      && strcontains(signalfx_detector.ec2_runner_disk.program_text, "'host.name', 'mountpoint', 'type', 'aws_account_id', 'aws_region', 'aws_tag_TenantName'")
      && strcontains(signalfx_detector.ec2_runner_disk.program_text, "disk > 80, '10m'")
      && strcontains(signalfx_detector.ec2_runner_disk.program_text, "off=when(disk < 75, '10m')")
      && strcontains(signalfx_detector.ec2_runner_disk.program_text, "auto_resolve_after='15m'")
      && !strcontains(signalfx_detector.ec2_runner_disk.program_text, "squashfs")
    )
    error_message = "Runner disk SignalFlow must monitor writable filesystems without paging on read-only squashfs mounts."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.ec2_runner_memory.program_text, "system.memory.usage")
      && strcontains(signalfx_detector.ec2_runner_memory.program_text, "filter('state', 'used', 'free', 'cached', 'buffered')")
      && strcontains(signalfx_detector.ec2_runner_memory.program_text, "memory > 90, '10m'")
      && strcontains(signalfx_detector.ec2_runner_memory.program_text, "off=when(memory < 80, '10m')")
      && strcontains(signalfx_detector.ec2_runner_memory.program_text, "auto_resolve_after='15m'")
    )
    error_message = "Runner memory SignalFlow must use the full memory-state total, stable thresholds, and inactive-stream resolution."
  }
}

run "fails_closed_when_required_dynamic_scope_is_empty" {
  command = plan

  variables {
    dynamic_variables = [
      {
        property               = "deployment.scope"
        alias                  = "Deployment scope"
        description            = "Required deployment-specific metric scope."
        values                 = []
        value_required         = true
        values_suggested       = []
        restricted_suggestions = true
      },
    ]
  }

  assert {
    condition = alltrue([
      for program_text in [
        signalfx_detector.ec2_runner_cpu.program_text,
        signalfx_detector.ec2_runner_disk.program_text,
        signalfx_detector.ec2_runner_memory.program_text,
      ] :
      strcontains(program_text, "filter('deployment.scope', '__forge_dynamic_scope_not_configured__')")
    ])
    error_message = "A required dynamic property without configured values must fail closed for every runner health detector."
  }
}
