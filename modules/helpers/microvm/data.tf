data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_subnet" "selected" {
  for_each = local.network_connector_subnets
  id       = each.value.subnet_id
}

locals {
  artifact_bucket_name = coalesce(
    var.artifact_bucket_name,
    "${data.aws_caller_identity.current.account_id}-forge-microvm-artifacts-${var.aws_region}",
  )
  artifact_prefix = "lambda-microvms"

  image_arn_pattern      = "arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:microvm-image:${var.image_name_prefix}-*"
  log_group_arn_pattern  = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/microvms/${var.image_name_prefix}-*"
  log_stream_arn_pattern = "${local.log_group_arn_pattern}:log-stream:*"

  network_connector_subnets = merge({}, [
    for connector_key, connector in var.network_connectors : {
      for subnet_id in connector.subnet_ids :
      "${connector_key}/${subnet_id}" => {
        connector_key = connector_key
        subnet_id     = subnet_id
      }
    }
  ]...)

  connector_stack_names = {
    for connector_key, connector in var.network_connectors :
    connector_key => format(
      "%s-%s",
      substr("forge-microvm-network-connector-${var.aws_region}-${replace(connector.name, "_", "-")}", 0, 119),
      substr(sha1(connector_key), 0, 8),
    )
  }

  connector_arns = {
    for connector_key, stack in aws_cloudformation_stack.connector :
    connector_key => stack.outputs["ConnectorArn"]
  }
}
