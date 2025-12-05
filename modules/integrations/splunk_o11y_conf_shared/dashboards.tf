resource "signalfx_dashboard_group" "forgecicd" {
  name        = "ForgeCICD Dashboards"
  description = ""
  teams       = [var.team]

  lifecycle {
    ignore_changes = [
      import_qualifier
    ]
  }
}

# Core platform health
module "dashboard_runner_ec2" {
  source = "./dashboards/runner_ec2"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.runner_ec2.tenant_names
  dynamic_variables = var.dashboard_variables.runner_ec2.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_runner_k8s" {
  source = "./dashboards/runner_k8s"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.runner_k8s.tenant_names
  dynamic_variables = var.dashboard_variables.runner_k8s.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_lambda" {
  source = "./dashboards/lambda"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.lambda.tenant_names
  dynamic_variables = var.dashboard_variables.lambda.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

# Messaging and storage
module "dashboard_sqs" {
  source = "./dashboards/sqs"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.sqs.tenant_names
  dynamic_variables = var.dashboard_variables.sqs.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_dynamodb" {
  source = "./dashboards/dynamodb"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.dynamodb.tenant_names
  dynamic_variables = var.dashboard_variables.dynamodb.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

module "dashboard_ebs" {
  source = "./dashboards/ebs"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.ebs.tenant_names
  dynamic_variables = var.dashboard_variables.ebs.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}

# Cost and usage
module "dashboard_billing" {
  source = "./dashboards/billing"

  providers = {
    signalfx = signalfx
  }

  tenant_names      = var.dashboard_variables.billing.tenant_names
  dynamic_variables = var.dashboard_variables.billing.dynamic_variables
  dashboard_group   = signalfx_dashboard_group.forgecicd.id
}
