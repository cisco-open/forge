resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_forgecicd" {
  name = "props/aws:cloudwatchlogs:forgecicd"

  variables = {
    "REPORT-forgecicd_cloudwatchlogs_runner_tenant_fields"          = "forgecicd_cloudwatchlogs_runner_tenant_fields"
    "REPORT-forgecicd_cloudwatchlogs_extract_log_time_message"      = "forgecicd_cloudwatchlogs_extract_log_time_message"
    "REPORT-forgecicd_cloudwatchlogs_runner_pages_github_repo_name" = "forgecicd_cloudwatchlogs_runner_pages_github_repo_name"
    "REPORT-forgecicd_cloudwatchlogs_runner_ci_result"              = "forgecicd_cloudwatchlogs_runner_ci_result"
    "REPORT-forgecicd_cloudwatchlogs_runner_gh_runner_version"      = "forgecicd_cloudwatchlogs_runner_gh_runner_version"
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
}

resource "splunk_configs_conf" "forgecicd_metadata" {
  name = "props/aws:metadata"

  variables = {
    "REPORT-forgecicd_metadata_tenant_fields" = "forgecicd_metadata_tenant_fields"
    "REPORT-forgecicd_metadata_instance_id"   = "forgecicd_metadata_instance_id"
    "REPORT-forgecicd_metadata_image_id"      = "forgecicd_metadata_image_id"
    "REPORT-forgecicd_metadata_instance_type" = "forgecicd_metadata_instance_type"
  }

  lifecycle {
    ignore_changes = [
      acl,
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
}
