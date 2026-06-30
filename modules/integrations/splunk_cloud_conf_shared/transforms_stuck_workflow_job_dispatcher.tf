resource "splunk_configs_conf" "forgecicd_stuck_workflow_job_dispatcher_delivery_attempt" {
  name = "transforms/forgecicd_stuck_workflow_job_dispatcher_delivery_attempt"

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

resource "splunk_configs_conf" "forgecicd_stuck_workflow_job_dispatcher_generic_fields" {
  name = "transforms/forgecicd_stuck_workflow_job_dispatcher_generic_fields"

  variables = {
    REGEX        = "(?=.*(?:redelivery_work_|splunk_webhook_skip|runner_lookup_failed|request_rejected|dispatcher_failed|worker_skip|runner_group))(?:^|\\s)(reason|repository|tenant|aws_region|workflow_job_id|workflow_job_url|runner|instance_id|state|delivery_id|guid|event|status|status_code)=([^\\s]+)"
    FORMAT       = "stuck_dispatcher_$1::$2"
    SOURCE_KEY   = "_raw"
    CLEAN_KEYS   = "0"
    MV_ADD       = "1"
    REPEAT_MATCH = "1"
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

resource "splunk_configs_conf" "forgecicd_stuck_workflow_job_dispatcher_key_fields" {
  name = "transforms/forgecicd_stuck_workflow_job_dispatcher_key_fields"

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

resource "splunk_configs_conf" "forgecicd_stuck_workflow_job_dispatcher_receiver_source" {
  name = "transforms/forgecicd_stuck_workflow_job_dispatcher_receiver_source"

  variables = {
    REGEX      = "([^:]+):\\/aws\\/lambda\\/(${var.stuck_workflow_job_dispatcher_name_prefix}):"
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

resource "splunk_configs_conf" "forgecicd_stuck_workflow_job_dispatcher_runner_group" {
  name = "transforms/forgecicd_stuck_workflow_job_dispatcher_runner_group"

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

resource "splunk_configs_conf" "forgecicd_stuck_workflow_job_dispatcher_worker_source" {
  name = "transforms/forgecicd_stuck_workflow_job_dispatcher_worker_source"

  variables = {
    REGEX      = "([^:]+):\\/aws\\/lambda\\/(${var.stuck_workflow_job_dispatcher_name_prefix}-worker):"
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
