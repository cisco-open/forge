locals {
  # Templatized userdata (cloud-init) file.
  user_data_prefix               = "${path.module}/template_files"
  userdata_template_post_install = "${local.user_data_prefix}/post_install.tftpl"

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
  for_each = toset(var.network_configs.subnet_ids)
  id       = each.value
}

data "external" "download_lambdas" {
  program = ["bash", "${path.module}/scripts/download_lambdas.sh", "/tmp/${var.runner_configs.prefix}/", "v7.10.0", "github-aws-runners/terraform-aws-github-runner"]
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
  hook_ssm_oses = toset([
    for key, val in var.runner_configs.runner_specs : val["runner_os"]
  ])
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
  #checkov:skip=CKV_TF_1:Module source uses Renovate-managed version tags; commit SHA pinning is an accepted policy tradeoff.
  source = "git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner?ref=v7.10.0"

  aws_region = var.aws_region

  vpc_id                    = var.network_configs.vpc_id
  subnet_ids                = var.network_configs.subnet_ids
  lambda_subnet_ids         = var.network_configs.lambda_subnet_ids
  lambda_security_group_ids = [aws_security_group.gh_runner_lambda_egress.id]
  kms_key_arn               = aws_kms_key.github.arn
  ghes_url                  = var.runner_configs.ghes_url
  prefix                    = var.runner_configs.prefix

  # For authenticating against the GitHub App we created.
  github_app = var.runner_configs.github_app

  eventbridge = {
    enable = true
  }

  lambda_tags          = var.tenant_configs.tags
  tags                 = var.tenant_configs.tags
  parameter_store_tags = var.tenant_configs.tags

  # Verbose logging.
  log_level = var.runner_configs.log_level

  # Retention period for the logs in days.
  logging_retention_in_days = var.runner_configs.logging_retention_in_days

  webhook_lambda_zip                = "${data.external.download_lambdas.result.path}/webhook.zip"
  runner_binaries_syncer_lambda_zip = "${data.external.download_lambdas.result.path}/runner-binaries-syncer.zip"
  runners_lambda_zip                = "${data.external.download_lambdas.result.path}/runners.zip"

  # Configure the various types of runners we provide, along with on-demand
  # versus standby pools, etc.
  multi_runner_config = {
    for key, val in var.runner_configs.runner_specs :
    key => {
      matcherConfig : {
        # Generate all unique combinations of extra_labels and combine them with runner_labels
        labelMatchers = concat(
          [val["runner_labels"]],
          concat([
            # Iterate over lengths from 1 to the length of extra_labels
            for length in range(1, length(val["extra_labels"]) + 1) : concat([
              # For each length, iterate over starting positions to slice the extra_labels
              for start in range(0, length(val["extra_labels"]) - length + 1) :
              # Combine runner_labels and the current slice of extra_labels
              concat(val["runner_labels"], slice(val["extra_labels"], start, start + length))
            ])
          ]...)
        )
        exactMatch             = true
        enableDynamicLabels    = val["enable_dynamic_labels"]
        ec2DynamicLabelsPolicy = val["ec2_dynamic_labels_policy"]
      }
      redrive_build_queue = val["redrive_build_queue"]
      runner_config = {
        runner_metadata_options = {
          "http_endpoint" : "enabled",
          "http_put_response_hop_limit" : 2,
          "http_tokens" : "optional",
          "instance_metadata_tags" : "enabled"
        }
        delay_webhook_event                                            = 0
        runner_ec2_tags                                                = var.tenant_configs.tags
        runner_os                                                      = val["runner_os"]
        runner_architecture                                            = val["runner_architecture"]
        runner_extra_labels                                            = val["extra_labels"]
        enable_ssm_on_runners                                          = true
        instance_types                                                 = val["instance_types"]
        runners_maximum_count                                          = val["max_instances"]
        scale_down_schedule_expression                                 = "cron(*/5 * * * ? *)"
        minimum_running_time_in_minutes                                = val["min_run_time"]
        runner_group_name                                              = var.runner_configs.runner_group_name
        enable_runner_binaries_syncer                                  = false
        enable_userdata                                                = val["enable_userdata"]
        scale_errors                                                   = var.runner_configs.scale_errors
        lambda_event_source_mapping_batch_size                         = val["lambda_event_source_mapping_batch_size"]
        lambda_event_source_mapping_maximum_batching_window_in_seconds = val["lambda_event_source_mapping_maximum_batching_window_in_seconds"]
        userdata_template                                              = "${local.user_data_prefix}/user_data_${val["runner_os"]}.tftpl"
        userdata_pre_install                                           = "# No pre-install steps."
        userdata_post_install = templatefile(
          local.userdata_template_post_install,
          {
            runner_user    = val["runner_user"]
            ecr_registries = var.tenant_configs.ecr_registries
          }
        )
        # The real hook scripts live (gzip+base64) in SSM; the runner hook is a
        # small wrapper that fetches+decompresses+runs them at job time. The
        # wrapper is small enough to inline in user_data. See hooks/ for the real
        # scripts and hook_job_*_<os>.tftpl for the wrappers.
        runner_hook_job_started = templatefile(
          "${local.user_data_prefix}/hook_job_started_${val["runner_os"]}.tftpl",
          {
            param_name = aws_ssm_parameter.hook_job_started[val["runner_os"]].name
            region     = var.aws_region
          }
        )
        runner_hook_job_completed = templatefile(
          "${local.user_data_prefix}/hook_job_completed_${val["runner_os"]}.tftpl",
          {
            param_name = aws_ssm_parameter.hook_job_completed[val["runner_os"]].name
            region     = var.aws_region
          }
        )
        enable_runner_detailed_monitoring = true
        runner_run_as                     = val["runner_user"]
        block_device_mappings             = val["block_device_mappings"]
        license_specifications            = val["license_specifications"]
        placement                         = val["placement"]
        use_dedicated_host                = val["use_dedicated_host"]
        runner_log_files = concat(
          // Linux/macOS-only logs
          val["runner_os"] == "windows" ? [] : [
            {
              "log_group_name" : "forge-logs",
              "prefix_log_group" : true,
              "file_path" : "/var/log/syslog",
              "log_stream_name" : "{instance_id}/syslog"
            },
          ],
          // Logs that exist on all OSes, with OS-specific paths
          [
            {
              "log_group_name" : "forge-logs",
              "prefix_log_group" : true,
              "file_path" : val["runner_os"] == "windows" ? "C:/UserData.log" : "/var/log/user-data.log",
              "log_stream_name" : "{instance_id}/user-data"
            },
            {
              "log_group_name" : "forge-logs",
              "prefix_log_group" : true,
              "file_path" : val["runner_os"] == "windows" ? "C:/actions-runner/_diag/Runner_*.log" : "/opt/actions-runner/_diag/Runner_**.log",
              "log_stream_name" : "{instance_id}/runner"
            },
            {
              "log_group_name" : "forge-logs",
              "prefix_log_group" : true,
              "file_path" : val["runner_os"] == "windows" ? "C:/Users/Administrator/AppData/Local/Temp/hook_*.log" : "/home/${val["runner_user"]}/hook.log",
              "log_stream_name" : "{instance_id}/hook"
            },
          ],
        )
        ami = {
          owners      = val["ami_owners"]
          filter      = val["ami_filter"]
          kms_key_arn = val["ami_kms_key_arn"]
        }
        instance_target_capacity_type = val["instance_target_capacity_type"]
        enable_job_queued_check       = false
        runner_iam_role_managed_policy_arns = concat(
          var.runner_configs.runner_iam_role_managed_policy_arns,
          [
            aws_iam_policy.ec2_tags.arn,
            aws_iam_policy.runner_hooks_ssm_read.arn,
          ],
        )
        vpc_id                          = val["vpc_id"]
        subnet_ids                      = val["subnet_ids"]
        enable_ephemeral_runners        = true
        create_service_linked_role_spot = true
        enable_organization_runners     = true
        job_queue_retention_in_seconds  = 172800
        pool_config                     = val["pool_config"]
        pool_runner_owner               = var.runner_configs.ghes_org
      }
    }
  }

  depends_on = [
    data.external.download_lambdas,
  ]
}
