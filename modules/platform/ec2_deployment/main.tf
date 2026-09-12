locals {
  # Templatized userdata (cloud-init) file.
  user_data_prefix               = "${path.module}/template_files"
  userdata_template_post_install = "${local.user_data_prefix}/post_install.tftpl"
  terraform_aws_github_runner_tags = merge(
    var.tenant_configs.tags,
    {
      terraform-aws-github-runner-ref = "fix-multi-runner-v2-routing"
    }
  )
  webhook_api_gateway_access_log_format = jsonencode({
    apiId                   = "$context.apiId"
    domainName              = "$context.domainName"
    errorMessage            = "$context.error.message"
    errorResponseType       = "$context.error.responseType"
    httpMethod              = "$context.httpMethod"
    integrationErrorMessage = "$context.integrationErrorMessage"
    integrationLatency      = "$context.integrationLatency"
    integrationStatus       = "$context.integrationStatus"
    path                    = "$context.path"
    protocol                = "$context.protocol"
    requestId               = "$context.requestId"
    requestTime             = "$context.requestTime"
    requestTimeEpoch        = "$context.requestTimeEpoch"
    responseLatency         = "$context.responseLatency"
    responseLength          = "$context.responseLength"
    routeKey                = "$context.routeKey"
    sourceIp                = "$context.identity.sourceIp"
    stage                   = "$context.stage"
    status                  = "$context.status"
    userAgent               = "$context.identity.userAgent"
  })
}

resource "aws_cloudwatch_log_group" "webhook_api_gateway_access" {
  #checkov:skip=CKV_AWS_158:KMS encryption for webhook access logs is deferred until the runner webhook path is tested with customer-managed keys.
  #checkov:skip=CKV_AWS_338:Webhook API access logs intentionally retain at most three days to limit request attribution data and ingestion cost.
  name              = "/aws/apigateway/${var.runner_configs.prefix}-github-action-webhook"
  retention_in_days = 3
  tags              = var.tenant_configs.tags
  tags_all          = var.tenant_configs.tags
}

# Enable AWS-managed encryption key.
resource "aws_kms_key" "github" {
  #checkov:skip=CKV_AWS_7:Runner KMS key rotation is deferred until module-managed key ownership and rotation behavior are regression-tested.
  #checkov:skip=CKV2_AWS_64:Runner KMS key policy hardening is deferred until module-managed key access paths are regression-tested.
  is_enabled = true

  tags = merge(
    var.tenant_configs.tags,
    {
      Name = "${var.runner_configs.prefix}-github-kms-key"
    }
  )
  tags_all = var.tenant_configs.tags
}

resource "aws_kms_alias" "github" {
  name          = "alias/${var.runner_configs.prefix}-github-kms-key"
  target_key_id = aws_kms_key.github.key_id
}

data "aws_subnet" "runner_subnet" {
  for_each = local.active_ec2_subnet_ids
  id       = each.value
}

data "external" "download_lambdas" {
  program = ["bash", "${path.module}/scripts/download_lambdas.sh", "/tmp/${var.runner_configs.prefix}/", "v7.11.0", "github-aws-runners/terraform-aws-github-runner"]
}

# ---------------------------------------------------------------------------
# Runner job-lifecycle hooks for osx/windows.
#
# Their hook scripts are too large to inline into EC2 user_data (16 KB limit,
# InvalidUserData.Malformed). We gzip+base64 them into SSM (Standard tier, free
# — the encoded payload is ~2 KB, well under the 4 KB Standard limit) and the
# instance fetches+decompresses them at boot. Linux hooks are small enough to
# inline and are handled directly in user_data_linux.tftpl.
# ---------------------------------------------------------------------------
locals {
  # Every runner OS delivers its (large) hook scripts via SSM; at job time the
  # runner runs a small wrapper (hook_job_<event>_<os>.tftpl) that fetches the
  # param, decompresses it, and execs the real hook (hooks/job_<event>_<os>).
  hook_ssm_oses = toset(values(local.active_ec2_runner_oses))
}

resource "aws_ssm_parameter" "hook_job_started" {
  #checkov:skip=CKV2_AWS_34:Hook payload is executable helper code, not a secret; write access is controlled by Terraform/IAM.
  for_each = local.hook_ssm_oses
  name     = "/forge/${var.runner_configs.prefix}/runner-hooks/${each.key}/job-started"
  type     = "String" # gzip+base64 payload, not a secret; Standard tier (free).
  value    = base64gzip(file("${local.user_data_prefix}/hooks/job_started_${each.key}"))
  tags     = var.tenant_configs.tags
}

resource "aws_ssm_parameter" "hook_job_completed" {
  #checkov:skip=CKV2_AWS_34:Hook payload is executable helper code, not a secret; write access is controlled by Terraform/IAM.
  for_each = local.hook_ssm_oses
  name     = "/forge/${var.runner_configs.prefix}/runner-hooks/${each.key}/job-completed"
  type     = "String"
  value    = base64gzip(file("${local.user_data_prefix}/hooks/job_completed_${each.key}"))
  tags     = var.tenant_configs.tags
}

data "aws_iam_policy_document" "runner_hooks_ssm_read" {
  statement {
    sid     = "ReadRunnerHookParameters"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = concat(
      [for p in aws_ssm_parameter.hook_job_started : p.arn],
      [for p in aws_ssm_parameter.hook_job_completed : p.arn],
    )
  }
}

resource "aws_iam_policy" "runner_hooks_ssm_read" {
  name        = "${var.runner_configs.prefix}-runner-hooks-ssm-read"
  description = "Allow runners to read their gzip'd job-hook scripts from SSM."
  policy      = data.aws_iam_policy_document.runner_hooks_ssm_read.json
  tags        = var.tenant_configs.tags
}


module "runners" {
  #checkov:skip=CKV_TF_1:Temporary upstream ref is required to validate multi-runner v2 compatibility before a release tag exists.
  source = "git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner?ref=feat-move-v1-state-to-v2"

  aws_region = var.aws_region

  prefix = var.runner_configs.prefix

  github_app = var.runner_configs.github_app

  experimental_features = ["multi-runner-v2"]

  global_config = {
    tags = local.global_config.tags
  }
  global_config_github                 = local.global_config.github
  global_config_lambda                 = local.global_config.lambda
  global_config_orchestration_provider = local.global_config.orchestration_provider
  global_config_ssm                    = local.global_config.ssm
  global_config_observability          = local.global_config.observability
  global_config_compute_provider = merge(local.global_config.compute_provider, {
    aws = merge(local.global_config.compute_provider.aws, {
      ec2 = merge(local.global_config.compute_provider.aws.ec2, {
        vpc_id     = var.network_configs.vpc_id
        subnet_ids = var.network_configs.subnet_ids
      })
    })
  })
  multi_runner_config = local.multi_runner_config

  depends_on = [
    data.external.download_lambdas,
  ]
}
