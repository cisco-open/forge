data "aws_sns_topic" "account_billing_alarm_topic" {
  name = "account-billing-alarm-topic"
}

resource "aws_budgets_budget" "budget_monthly_overall" {
  for_each = var.ec2_runner_specs

  name              = "Tenant (${local.runner_prefix} ${each.key}) => Runner Type Monthly Budget"
  budget_type       = "COST"
  limit_amount      = each.value.aws_budget.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2020-01-01_00:00"

  cost_filter {
    # Filter by service type (case-sensitive).
    name = "TagKeyValue"
    values = [
      "user:Name${"$"}${local.runner_prefix}-${each.key}-action-runner"
    ]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"
    subscriber_sns_topic_arns = [
      data.aws_sns_topic.account_billing_alarm_topic.arn
    ]
  }

  tags = local.all_security_tags
}
