locals {
  # Templatized userdata (cloud-init) file.
  user_data_prefix                   = "${path.module}/template_files"
  userdata_template_post_install     = "${local.user_data_prefix}/post_install.tftpl"
  user_data_template_runner          = "${local.user_data_prefix}/user_data.tftpl"
  runner_template_hook_job_started   = "${local.user_data_prefix}/hook_job_started.tftpl"
  runner_template_hook_job_completed = "${local.user_data_prefix}/hook_job_completed.tftpl"

  runner_hook_job_started   = file(local.runner_template_hook_job_started)
  runner_hook_job_completed = file(local.runner_template_hook_job_completed)

  userdata_post_install = templatefile(
    local.userdata_template_post_install,
    {
      runner_user    = "ubuntu"
      ecr_registries = var.tenant_configs.ecr_registries
    }
  )

  # Security settings for the binaries (lambdas) stored in S3.
  s3_security_settings = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

}

# Enable AWS-managed encryption key.
resource "aws_kms_key" "github" {
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
  program = ["bash", "${path.module}/scripts/download_lambdas.sh", "/tmp/${var.runner_configs.prefix}/", "v6.9.0"]
}

module "runners" {
  source = "git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner?ref=v6.9.0"

  aws_region = var.aws_region

  vpc_id     = var.network_configs.vpc_id
  subnet_ids = var.network_configs.subnet_ids
  runner_additional_security_group_ids = [
    aws_security_group.gh_runner_egress.id,
  ]
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

  lambda_tags = var.tenant_configs.tags
  tags        = var.tenant_configs.tags

  # Verbose logging.
  log_level = var.runner_configs.log_level

  # Retention period for the logs in days.
  logging_retention_in_days = var.runner_configs.logging_retention_in_days

  webhook_lambda_zip                = "/tmp/${var.runner_configs.prefix}/webhook.zip"
  runner_binaries_syncer_lambda_zip = "/tmp/${var.runner_configs.prefix}/runner-binaries-syncer.zip"
  runners_lambda_zip                = "/tmp/${var.runner_configs.prefix}/runners.zip"

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
        exactMatch = true
      }
      redrive_build_queue = {
        enabled         = true
        maxReceiveCount = 10
      }
      delay_webhook_event = 0
      runner_config = {
        runner_metadata_options = {
          "http_endpoint" : "enabled",
          "http_put_response_hop_limit" : 2,
          "http_tokens" : "optional",
          "instance_metadata_tags" : "enabled"
        }
        runner_ec2_tags                      = var.tenant_configs.tags
        runner_binaries_s3_sse_configuration = local.s3_security_settings
        runner_os                            = val["runner_os"]
        runner_architecture                  = val["runner_architecture"]
        runner_extra_labels                  = val["extra_labels"]
        enable_ssm_on_runners                = true
        instance_types                       = val["instance_types"]
        runners_maximum_count                = val["max_instances"]
        scale_down_schedule_expression       = "cron(*/5 * * * ? *)"
        minimum_running_time_in_minutes      = val["min_run_time"]
        runner_group_name                    = var.runner_configs.runner_group_name
        enable_runner_binaries_syncer        = false
        enable_userdata                      = val["enable_userdata"]
        userdata_template                    = local.user_data_template_runner
        userdata_pre_install                 = "# No pre-install steps."
        userdata_post_install                = local.userdata_post_install
        runner_hook_job_started              = local.runner_hook_job_started
        runner_hook_job_completed            = local.runner_hook_job_completed
        enable_runner_detailed_monitoring    = true
        runner_run_as                        = val["runner_user"]
        block_device_mappings                = val["block_device_mappings"]
        runner_log_files = [
          {
            "log_group_name" : "forge-logs",
            "prefix_log_group" : true,
            "file_path" : "/var/log/syslog",
            "log_stream_name" : "{instance_id}/syslog"
          },
          {
            "log_group_name" : "forge-logs",
            "prefix_log_group" : true,
            "file_path" : "/var/log/user-data.log",
            "log_stream_name" : "{instance_id}/user-data"
          },
          {
            "log_group_name" : "forge-logs",
            "prefix_log_group" : true,
            "file_path" : "/opt/actions-runner/_diag/Runner_**.log",
            "log_stream_name" : "{instance_id}/runner"
          },
          {
            "log_group_name" : "forge-logs",
            "prefix_log_group" : true,
            "file_path" : "/home/ubuntu/hook.log",
            "log_stream_name" : "{instance_id}/hook"
          },
        ]
        ami_owners                    = val["ami_owners"]
        ami_filter                    = val["ami_filter"]
        ami_kms_key_arn               = val["ami_kms_key_arn"]
        instance_target_capacity_type = val["instance_target_capacity_type"]
        enable_job_queued_check       = false
        runner_iam_role_managed_policy_arns = concat(
          var.runner_configs.runner_iam_role_managed_policy_arns,
          [
            aws_iam_policy.ec2_tags.arn,
          ]
        )
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
