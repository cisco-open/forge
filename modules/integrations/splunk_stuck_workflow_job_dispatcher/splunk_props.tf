moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_cloudwatchlogs_props["aws:cloudwatchlogs"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_cloudwatchlogs_props
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_cloudwatchlogs_props" {
  name = "props/aws:cloudwatchlogs"

  variables = {
    "REPORT-stuck_workflow_job_dispatcher_delivery_attempt" = "stuck_workflow_job_dispatcher_delivery_attempt"
    "REPORT-stuck_workflow_job_dispatcher_generic_fields"   = "stuck_workflow_job_dispatcher_generic_fields"
    "REPORT-stuck_workflow_job_dispatcher_key_fields"       = "stuck_workflow_job_dispatcher_key_fields"
    "REPORT-stuck_workflow_job_dispatcher_receiver_source"  = "stuck_workflow_job_dispatcher_receiver_source"
    "REPORT-stuck_workflow_job_dispatcher_runner_group"     = "stuck_workflow_job_dispatcher_runner_group"
    "REPORT-stuck_workflow_job_dispatcher_worker_source"    = "stuck_workflow_job_dispatcher_worker_source"
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
      variables["EVAL-github_action"],
      variables["EVAL-github_completed_at"],
      variables["EVAL-github_conclusion"],
      variables["EVAL-github_created_at"],
      variables["EVAL-github_delivery"],
      variables["EVAL-github_event"],
      variables["EVAL-github_head_branch"],
      variables["EVAL-github_head_sha"],
      variables["EVAL-github_hook_id"],
      variables["EVAL-github_hook_installation_target_id"],
      variables["EVAL-github_job_name"],
      variables["EVAL-github_labels"],
      variables["EVAL-github_repository"],
      variables["EVAL-github_run_attempt"],
      variables["EVAL-github_run_id"],
      variables["EVAL-github_run_url"],
      variables["EVAL-github_started_at"],
      variables["EVAL-github_status"],
      variables["EVAL-github_workflow_job_id"],
      variables["EVAL-github_workflow_job_url"],
      variables["EVAL-github_workflow_name"],
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
      variables["REPORT-forgecicd_cloudwatchlogs_global_lambda_tenant_fields"],
      variables["REPORT-forgecicd_cloudwatchlogs_lambda_tenant_fields"],
      variables["REPORT-forgecicd_eks_control_plane_fields"],
      variables["REPORT-forgecicd_extra_lambda_ec2_tenant_fields"],
      variables["REPORT-forgecicd_extra_lambda_tenant_fields"],
      variables["REPORT-forgecicd_trust_validation"],
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
    splunk_configs_conf.stuck_workflow_job_dispatcher_delivery_attempt,
    splunk_configs_conf.stuck_workflow_job_dispatcher_generic_fields,
    splunk_configs_conf.stuck_workflow_job_dispatcher_key_fields,
    splunk_configs_conf.stuck_workflow_job_dispatcher_receiver_source,
    splunk_configs_conf.stuck_workflow_job_dispatcher_runner_group,
    splunk_configs_conf.stuck_workflow_job_dispatcher_worker_source,
  ]
}
