mock_provider "signalfx" {
  mock_resource "signalfx_detector" {}
}

variables {
  detector_name_prefix   = "Forge Prod"
  detector_notifications = ["Email,forge@example.com"]
  team                   = "forge-team"
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
      values_suggested       = ["us-east-1"]
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

run "creates_regional_platform_detector" {
  command = plan

  assert {
    condition = (
      signalfx_detector.aws_regional_platform_health.name == "Forge Prod AWS regional platform health"
      && signalfx_detector.aws_regional_platform_health.teams == toset(["forge-team"])
      && length(signalfx_detector.aws_regional_platform_health.rule) == 3
    )
    error_message = "The regional platform detector must keep its name, team, and three justified queue-health rules."
  }

  assert {
    condition = (
      strcontains(signalfx_detector.aws_regional_platform_health.program_text, "queue_oldest_age > 300, '10m'")
      && strcontains(signalfx_detector.aws_regional_platform_health.program_text, "(queue_oldest_age > 75) and (queue_visible_messages > 10), '10m'")
      && length(regexall("off=when\\(queue_oldest_age < 60, '15m'\\)", signalfx_detector.aws_regional_platform_health.program_text)) == 2
      && strcontains(signalfx_detector.aws_regional_platform_health.program_text, "dlq_sends > 0")
      && !strcontains(signalfx_detector.aws_regional_platform_health.program_text, "detect(when(throttle")
    )
    error_message = "Detector SignalFlow must preserve stable queue thresholds and must not page on region-specific Lambda throttle baselines."
  }

  assert {
    condition = alltrue([
      for rule in signalfx_detector.aws_regional_platform_health.rule :
      toset(rule.notifications) == toset(["Email,forge@example.com"])
    ])
    error_message = "Every regional platform detector rule must use the configured notification routing."
  }
}
