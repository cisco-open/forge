resource "aws_budgets_budget" "budget_monthly_overall" {
  for_each = var.ec2_runner_specs

  name              = "Tenant (${var.deployment_config.prefix} ${each.key}) => Runner Type Monthly Budget"
  budget_type       = "COST"
  limit_amount      = each.value.aws_budget.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2020-01-01_00:00"

  cost_filter {
    # Filter by service type (case-sensitive).
    name = "TagKeyValue"
    values = [
      "user:Name${"$"}${var.deployment_config.prefix}-${each.key}-action-runner"
    ]
  }

  tags = local.all_security_tags
}
