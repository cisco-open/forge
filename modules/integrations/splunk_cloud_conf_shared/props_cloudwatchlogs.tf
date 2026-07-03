
resource "splunk_configs_conf" "forgecicd_cloudwatchlogs" {
  name = "props/aws:cloudwatchlogs"

  variables = {
    "REPORT-forgecicd_cloudwatchlogs_lambda_tenant_fields"            = "forgecicd_cloudwatchlogs_lambda_tenant_fields"
    "REPORT-forgecicd_cloudwatchlogs_global_lambda_tenant_fields"     = "forgecicd_cloudwatchlogs_global_lambda_tenant_fields"
    "REPORT-forgecicd_dispatch_to_runner_rejection_fields"            = "forgecicd_dispatch_to_runner_rejection_fields"
    "REPORT-forgecicd_extra_lambda_tenant_fields"                     = "forgecicd_extra_lambda_tenant_fields"
    "REPORT-forgecicd_trust_validation"                               = "forgecicd_trust_validation"
    "REPORT-forgecicd_extra_lambda_ec2_tenant_fields"                 = "forgecicd_extra_lambda_ec2_tenant_fields"
    "REPORT-forgecicd_eks_control_plane_fields"                       = "forgecicd_eks_control_plane_fields"
    "REPORT-forgecicd_pool_idle_runners"                              = "forgecicd_pool_idle_runners"
    "REPORT-forgecicd_pool_target_size"                               = "forgecicd_pool_target_size"
    "REPORT-forgecicd_pool_top_up"                                    = "forgecicd_pool_top_up"
    "REPORT-forgecicd_pool_top_up_cap"                                = "forgecicd_pool_top_up_cap"
    "REPORT-forgecicd_scale_down_aws_runner_instance_id"              = "forgecicd_scale_down_aws_runner_instance_id"
    "REPORT-forgecicd_scale_down_orphan_runner_instance_id"           = "forgecicd_scale_down_orphan_runner_instance_id"
    "REPORT-forgecicd_scale_down_runner_instance_id"                  = "forgecicd_scale_down_runner_instance_id"
    "REPORT-forgecicd_stuck_workflow_job_dispatcher_delivery_attempt" = "forgecicd_stuck_workflow_job_dispatcher_delivery_attempt"
    "REPORT-forgecicd_stuck_workflow_job_dispatcher_generic_fields"   = "forgecicd_stuck_workflow_job_dispatcher_generic_fields"
    "REPORT-forgecicd_stuck_workflow_job_dispatcher_key_fields"       = "forgecicd_stuck_workflow_job_dispatcher_key_fields"
    "REPORT-forgecicd_stuck_workflow_job_dispatcher_receiver_source"  = "forgecicd_stuck_workflow_job_dispatcher_receiver_source"
    "REPORT-forgecicd_stuck_workflow_job_dispatcher_runner_group"     = "forgecicd_stuck_workflow_job_dispatcher_runner_group"
    "REPORT-forgecicd_stuck_workflow_job_dispatcher_worker_source"    = "forgecicd_stuck_workflow_job_dispatcher_worker_source"
    "EVAL-github_action"                                              = "'github.action'"
    "EVAL-github_completed_at"                                        = "'github.completed_at'"
    "EVAL-github_conclusion"                                          = "'github.conclusion'"
    "EVAL-github_created_at"                                          = "'github.created_at'"
    "EVAL-github_delivery"                                            = "'github.github-delivery'"
    "EVAL-github_event"                                               = "'github.github-event'"
    "EVAL-github_head_branch"                                         = "'github.headBranch'"
    "EVAL-github_head_sha"                                            = "'github.headSha'"
    "EVAL-github_hook_id"                                             = "'github.github-hook-id'"
    "EVAL-github_hook_installation_target_id"                         = "'github.github-hook-installation-target-id'"
    "EVAL-github_job_name"                                            = "'github.name'"
    "EVAL-github_labels"                                              = "mvjoin('github.labels', \", \")"
    "EVAL-github_repository"                                          = "'github.repository'"
    "EVAL-github_run_attempt"                                         = "'github.runAttempt'"
    "EVAL-github_run_id"                                              = "'github.runId'"
    "EVAL-github_run_url"                                             = "'github.runUrl'"
    "EVAL-github_started_at"                                          = "'github.started_at'"
    "EVAL-github_status"                                              = "'github.status'"
    "EVAL-github_workflow_job_id"                                     = "'github.workflowJobId'"
    "EVAL-github_workflow_job_url"                                    = "'github.workflowJobUrl'"
    "EVAL-github_workflow_name"                                       = "'github.workflowName'"
  }

  acl {
    read  = var.splunk_conf.acl.read
    write = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["ADD_EXTRA_TIME_FIELDS"],
      variables["ANNOTATE_PUNCT"],
      variables["AUTO_KV_JSON"],
      variables["BREAK_ONLY_BEFORE"],
      variables["BREAK_ONLY_BEFORE_DATE"],
      variables["CHARSET"],
      variables["DATETIME_CONFIG"],
      variables["DEPTH_LIMIT"],
      variables["DETERMINE_TIMESTAMP_DATE_WITH_SYSTEM_TIME"],
      variables["HEADER_MODE"],
      variables["LB_CHUNK_BREAKER_TRUNCATE"],
      variables["LEARN_MODEL"],
      variables["LEARN_SOURCETYPE"],
      variables["LINE_BREAKER_LOOKBEHIND"],
      variables["MATCH_LIMIT"],
      variables["MAX_DAYS_AGO"],
      variables["MAX_DAYS_HENCE"],
      variables["MAX_DIFF_SECS_AGO"],
      variables["MAX_DIFF_SECS_HENCE"],
      variables["MAX_EVENTS"],
      variables["MAX_EXPECTED_EVENT_LINES"],
      variables["MAX_TIMESTAMP_LOOKAHEAD"],
      variables["MUST_BREAK_AFTER"],
      variables["MUST_NOT_BREAK_AFTER"],
      variables["MUST_NOT_BREAK_BEFORE"],
      variables["SEGMENTATION"],
      variables["SEGMENTATION-all"],
      variables["SEGMENTATION-inner"],
      variables["SEGMENTATION-outer"],
      variables["SEGMENTATION-raw"],
      variables["SEGMENTATION-standard"],
      variables["SHOULD_LINEMERGE"],
      variables["TRANSFORMS"],
      variables["TRUNCATE"],
      variables["detect_trailing_nulls"],
      variables["disabled"],
      variables["maxDist"],
      variables["priority"],
      variables["sourcetype"],
      variables["termFrequencyWeightedDist"],
      variables["unarchive_cmd_start_mode"],
    ]
  }
  depends_on = [
    splunk_configs_conf.forgecicd_cloudwatchlogs_lambda_tenant_fields,
    splunk_configs_conf.forgecicd_cloudwatchlogs_global_lambda_tenant_fields,
    splunk_configs_conf.forgecicd_dispatch_to_runner_rejection_fields,
    splunk_configs_conf.forgecicd_extra_lambda_tenant_fields,
    splunk_configs_conf.forgecicd_extra_lambda_ec2_tenant_fields,
    splunk_configs_conf.forgecicd_trust_validation,
    splunk_configs_conf.forgecicd_eks_control_plane_fields,
    splunk_configs_conf.forgecicd_pool_idle_runners,
    splunk_configs_conf.forgecicd_pool_target_size,
    splunk_configs_conf.forgecicd_pool_top_up,
    splunk_configs_conf.forgecicd_pool_top_up_cap,
    splunk_configs_conf.forgecicd_scale_down_aws_runner_instance_id,
    splunk_configs_conf.forgecicd_scale_down_orphan_runner_instance_id,
    splunk_configs_conf.forgecicd_scale_down_runner_instance_id,
    splunk_configs_conf.forgecicd_stuck_workflow_job_dispatcher_delivery_attempt,
    splunk_configs_conf.forgecicd_stuck_workflow_job_dispatcher_generic_fields,
    splunk_configs_conf.forgecicd_stuck_workflow_job_dispatcher_key_fields,
    splunk_configs_conf.forgecicd_stuck_workflow_job_dispatcher_receiver_source,
    splunk_configs_conf.forgecicd_stuck_workflow_job_dispatcher_runner_group,
    splunk_configs_conf.forgecicd_stuck_workflow_job_dispatcher_worker_source
  ]
}
