moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_extractions["delivery_attempt"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_delivery_attempt
}

moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_extractions["generic_fields"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_generic_fields
}

moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_extractions["key_fields"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_key_fields
}

moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_extractions["receiver_source"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_receiver_source
}

moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_extractions["runner_group"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_runner_group
}

moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_extractions["worker_source"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_worker_source
}

moved {
  from = splunk_configs_conf.stuck_workflow_job_dispatcher_cloudwatchlogs_props["aws:cloudwatchlogs"]
  to   = splunk_configs_conf.stuck_workflow_job_dispatcher_cloudwatchlogs_props
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_delivery_attempt" {
  name = "transforms/stuck_workflow_job_dispatcher_delivery_attempt"

  variables = {
    REGEX      = "delivery_id=([^\\s]+)\\s+guid=([^\\s]+)\\s+event=([^\\s]+)\\s+delivered_at=([^\\s]+)\\s+status=([^\\s]+)\\s+status_code=([^\\s]+)\\s+repository_id=([^\\s]+)"
    FORMAT     = "stuck_dispatcher_delivery_id::$1 stuck_dispatcher_delivery_guid::$2 stuck_dispatcher_github_event::$3 stuck_dispatcher_delivered_at::$4 stuck_dispatcher_delivery_status::$5 stuck_dispatcher_delivery_status_code::$6 stuck_dispatcher_repository_id::$7"
    SOURCE_KEY = "_raw"
    CLEAN_KEYS = "0"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["MV_ADD"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_generic_fields" {
  name = "transforms/stuck_workflow_job_dispatcher_generic_fields"

  variables = {
    REGEX        = "(?=.*(?:redelivery_work_|splunk_webhook_skip|runner_lookup_failed|request_rejected|dispatcher_failed|worker_skip|runner_group))(?:^|\\s)(reason|repository|tenant|aws_region|workflow_job_id|workflow_job_url|runner|instance_id|state|delivery_id|guid|event|status|status_code)=([^\\s]+)"
    FORMAT       = "stuck_dispatcher_$1::$2"
    SOURCE_KEY   = "_raw"
    CLEAN_KEYS   = "0"
    MV_ADD       = "1"
    REPEAT_MATCH = "true"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_key_fields" {
  name = "transforms/stuck_workflow_job_dispatcher_key_fields"

  variables = {
    REGEX      = "(?=.*(?:redelivery_work_|splunk_webhook_skip|runner_lookup_failed|dispatcher_failed|redelivery_preflight|redelivery_execute|redelivery_work_completed|redelivery_work_failed|worker_skip))key=([^#\\s]+)#([^#\\s]+)#([^#\\s]+)#([^\\s]+)"
    FORMAT     = "stuck_dispatcher_tenant::$1 stuck_dispatcher_aws_region::$2 stuck_dispatcher_repository::$3 stuck_dispatcher_workflow_job_id::$4 stuck_dispatcher_key::$1#$2#$3#$4"
    SOURCE_KEY = "_raw"
    CLEAN_KEYS = "0"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["MV_ADD"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_receiver_source" {
  name = "transforms/stuck_workflow_job_dispatcher_receiver_source"

  variables = {
    REGEX      = "([^:]+):\\/aws\\/lambda\\/(${var.name_prefix}):"
    FORMAT     = "aws_region::$1 stuck_dispatcher_lambda::$2 stuck_dispatcher_component::receiver"
    SOURCE_KEY = "source"
    CLEAN_KEYS = "0"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["MV_ADD"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_runner_group" {
  name = "transforms/stuck_workflow_job_dispatcher_runner_group"

  variables = {
    REGEX      = "runner_group\\s+queue=([^\\s]+)\\s+runner=([^\\s]+)\\s+stuck=([0-9]+)\\s+instances=([0-9]+)\\s+executed=([0-9]+)\\s+free=([0-9]+)\\s+skip=([0-9]+)"
    FORMAT     = "stuck_dispatcher_queue::$1 stuck_dispatcher_runner::$2 stuck_dispatcher_stuck_jobs::$3 stuck_dispatcher_runner_instances::$4 stuck_dispatcher_executed_jobs::$5 stuck_dispatcher_free_runners::$6 stuck_dispatcher_skipped_for_free_runner::$7"
    SOURCE_KEY = "_raw"
    CLEAN_KEYS = "0"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["MV_ADD"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher_worker_source" {
  name = "transforms/stuck_workflow_job_dispatcher_worker_source"

  variables = {
    REGEX      = "([^:]+):\\/aws\\/lambda\\/(${var.name_prefix}-worker):"
    FORMAT     = "aws_region::$1 stuck_dispatcher_lambda::$2 stuck_dispatcher_component::worker"
    SOURCE_KEY = "source"
    CLEAN_KEYS = "0"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["MV_ADD"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
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
