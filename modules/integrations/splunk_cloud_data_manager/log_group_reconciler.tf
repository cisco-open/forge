locals {
  # Keep provider and module instance keys derived only from input variables.
  # Resource attributes are deliberately excluded so OpenTofu can resolve the
  # regional graph before it creates the Splunk-managed stacks.
  splunk_dm_stack_regions = toset(distinct(concat(
    var.cloudwatch_log_groups_config.enabled ? concat(
      [var.aws_region],
      var.cloudwatch_log_groups_config.regions,
    ) : [],
    var.custom_cloudwatch_log_groups_config.enabled ? concat(
      [var.aws_region],
      [
        for config in var.custom_cloudwatch_log_groups_config.log_group_name_prefixes :
        config.region
      ],
    ) : [],
    var.security_metadata_config.enabled ? concat(
      [var.aws_region],
      var.security_metadata_config.regions,
    ) : [],
    [
      for config in values(local.splunk_s3_logs_inputs) :
      config.iam_region
    ],
  )))

  # Normalize all seven CloudFormation stack collections so one reconciler can
  # receive the complete, ordered stack-ID list for its region.
  splunk_dm_cloudformation_stacks = merge(
    {
      for _, stack in aws_cloudformation_stack.cf_splunk_cloudwatch_iam_region :
      "cloudwatch/${var.aws_region}" => {
        region       = var.aws_region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
    {
      for region, stack in aws_cloudformation_stack.cf_splunk_cloudwatch_region :
      "cloudwatch/${region}" => {
        region       = region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
    {
      for _, stack in aws_cloudformation_stack.cf_splunk_custom_cloudwatch_iam_region :
      "custom-cloudwatch/${var.aws_region}" => {
        region       = var.aws_region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
    {
      for region, stack in aws_cloudformation_stack.cf_splunk_custom_cloudwatch_region :
      "custom-cloudwatch/${region}" => {
        region       = region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
    {
      for _, stack in aws_cloudformation_stack.cf_splunk_security_metadata_iam_region :
      "security-metadata/${var.aws_region}" => {
        region       = var.aws_region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
    {
      for region, stack in aws_cloudformation_stack.cf_splunk_security_metadata_region :
      "security-metadata/${region}" => {
        region       = region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
    {
      for input_name, stack in aws_cloudformation_stack.cf_splunk_s3_logs_iam_region :
      "s3/${input_name}" => {
        region       = local.splunk_s3_logs_inputs[input_name].iam_region
        stack_id     = stack.id
        template_url = stack.template_url
        tags         = tomap(stack.tags_all)
      }
    },
  )

  splunk_dm_cloudformation_stacks_by_region = {
    for region in local.splunk_dm_stack_regions :
    region => {
      stack_ids = sort([
        for stack in values(local.splunk_dm_cloudformation_stacks) :
        stack.stack_id
        if stack.region == region
      ])

      stacks = {
        for stack_key, stack in local.splunk_dm_cloudformation_stacks :
        stack_key => {
          stack_id     = stack.stack_id
          template_url = stack.template_url
          tags         = stack.tags
        }
        if stack.region == region
      }
    }
  }
}

module "splunk_dm_log_group_reconciler" {
  for_each = local.splunk_dm_stack_regions

  source = "./log_group_reconciler"

  name   = join("-", local.config_aliases)
  region = each.key
  tags   = local.all_security_tags
}

resource "aws_lambda_invocation" "splunk_dm_log_group_reconciler" {
  for_each = local.splunk_dm_cloudformation_stacks_by_region

  function_name   = module.splunk_dm_log_group_reconciler[each.key].lambda_function_name
  lifecycle_scope = "CREATE_ONLY"
  region          = each.key

  input = jsonencode({
    region    = each.key
    stack_ids = each.value.stack_ids
    tags      = local.all_security_tags
    revision = sha256(jsonencode({
      handler_sha256 = filesha256("${path.module}/log_group_reconciler/lambda/log_group_reconciler.py")
      stacks         = each.value.stacks
    }))
  })

  depends_on = [
    module.splunk_dm_log_group_reconciler,
  ]
}
