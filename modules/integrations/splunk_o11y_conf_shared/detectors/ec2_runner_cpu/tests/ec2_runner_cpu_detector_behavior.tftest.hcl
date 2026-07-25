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
  ]
}

run "creates_scoped_runner_cpu_detector" {
  command = plan

  assert {
    condition = (
      signalfx_detector.ec2_runner_cpu.name == "Forge Prod EC2 runner high CPU"
      && signalfx_detector.ec2_runner_cpu.teams == toset(["forge-team"])
      && length(signalfx_detector.ec2_runner_cpu.rule) == 1
      && toset(signalfx_detector.ec2_runner_cpu.rule[0].notifications) == toset(["Email,forge@example.com"])
    )
    error_message = "The runner CPU detector must keep its name, owner team, and configured alert route."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.ec2_runner_cpu.program_text, "^aws.ec2.cpu.utilization")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "filter('aws_region', 'us-east-1') or filter('aws_region', 'us-west-2')")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "filter('aws_tag_TenantName', 'tenant-a') or filter('aws_tag_TenantName', 'tenant-b')")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "cpu > 90, '10m'")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "off=when(cpu < 70, '10m')")
      && strcontains(signalfx_detector.ec2_runner_cpu.program_text, "auto_resolve_after='15m'")
    )
    error_message = "Runner CPU SignalFlow must be production-scoped, use stable thresholds, and auto-resolve inactive runner streams."
  }
}
