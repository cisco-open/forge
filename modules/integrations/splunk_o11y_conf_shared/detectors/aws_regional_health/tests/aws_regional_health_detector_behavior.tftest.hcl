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
      strcontains(signalfx_detector.aws_regional_platform_health.program_text, "filter('aws_account_id', '111111111111')")
      && strcontains(signalfx_detector.aws_regional_platform_health.program_text, "filter('aws_region', 'us-east-1')")
      && strcontains(signalfx_detector.aws_regional_platform_health.program_text, "filter('aws_tag_ProductFamilyName', 'Forge MT')")
      && strcontains(signalfx_detector.aws_regional_platform_health.program_text, "filter('aws_tag_Environment', 'prod')")
    )
    error_message = "The regional platform detector must retain every configured dynamic-property scope."
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

  assert {
    condition = (
      signalfx_detector.aws_control_plane_health.name == "Forge Prod AWS Lambda control-plane health"
      && signalfx_detector.aws_control_plane_health.teams == toset(["forge-team"])
      && length(signalfx_detector.aws_control_plane_health.rule) == 2
      && strcontains(signalfx_detector.aws_control_plane_health.program_text, "not filter('aws_tag_TenantName', '*')")
      && strcontains(signalfx_detector.aws_control_plane_health.program_text, "not filter('aws_function_name', 'splunk-dependency-monitor-*')")
      && strcontains(signalfx_detector.aws_control_plane_health.program_text, "lambda_errors > 0, '10m'")
      && strcontains(signalfx_detector.aws_control_plane_health.program_text, "lambda_throttles > 0, '5m'")
      && !strcontains(signalfx_detector.aws_control_plane_health.program_text, "ApproximateAgeOfOldestMessage")
    )
    error_message = "The Lambda control-plane detector must exclude tenant resources and contain only sustained Lambda failures."
  }

  assert {
    condition = alltrue([
      for rule in signalfx_detector.aws_control_plane_health.rule :
      toset(rule.notifications) == toset(["Email,forge@example.com"])
    ])
    error_message = "Every Lambda control-plane detector rule must use the configured notification routing."
  }

  assert {
    condition = (
      signalfx_detector.aws_sqs_control_plane_health.name == "Forge Prod AWS SQS control-plane health"
      && signalfx_detector.aws_sqs_control_plane_health.teams == toset(["forge-team"])
      && length(signalfx_detector.aws_sqs_control_plane_health.rule) == 4
      && strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "not filter('aws_tag_TenantName', '*')")
      && strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "filter('QueueName', 'splunk-dependency-monitor-*-failed-invocations')")
      && strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "dependency_monitor_failed_invocations > 0")
      && strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "queue_oldest_age > 300, '10m'")
      && strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "filter('QueueName', '*dead-letter*', '*dead_letter*', '*dlq*', '*DLQ*')")
      && strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "dlq_visible_messages > 0, '5m'")
      && !strcontains(signalfx_detector.aws_sqs_control_plane_health.program_text, "data('Errors'")
    )
    error_message = "The SQS control-plane detector must exclude tenant resources and alert when dependency-monitor retries are exhausted."
  }

  assert {
    condition = alltrue([
      for rule in signalfx_detector.aws_sqs_control_plane_health.rule :
      toset(rule.notifications) == toset(["Email,forge@example.com"])
    ])
    error_message = "Every SQS control-plane detector rule must use the configured notification routing."
  }
}
