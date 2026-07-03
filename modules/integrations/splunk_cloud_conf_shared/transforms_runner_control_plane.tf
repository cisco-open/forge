resource "splunk_configs_conf" "forgecicd_dispatch_to_runner_rejection_fields" {
  name = "transforms/forgecicd_dispatch_to_runner_rejection_fields"

  variables = {
    REGEX      = "Received event contains runner labels '([^']+)' from '([^']+)' that are not accepted\\. - Job ID: ([0-9]+), Job Name: (.*), Run ID: ([0-9]+)"
    FORMAT     = "forgecicd_dispatcher_runner_labels::$1 forgecicd_dispatcher_repository::$2 forgecicd_dispatcher_job_id::$3 forgecicd_dispatcher_job_name::$4 forgecicd_dispatcher_run_id::$5"
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

resource "splunk_configs_conf" "forgecicd_pool_target_size" {
  name = "transforms/forgecicd_pool_target_size"

  variables = {
    REGEX      = "Checking current pool size against pool of size: ([0-9]+)"
    FORMAT     = "forgecicd_pool_target_size::$1"
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

resource "splunk_configs_conf" "forgecicd_pool_top_up" {
  name = "transforms/forgecicd_pool_top_up"

  variables = {
    REGEX      = "The pool will be topped up with ([0-9]+) runners\\."
    FORMAT     = "forgecicd_pool_top_up::$1"
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

resource "splunk_configs_conf" "forgecicd_pool_idle_runners" {
  name = "transforms/forgecicd_pool_idle_runners"

  variables = {
    REGEX      = "Pool will not be topped up\\. Found ([0-9]+) managed idle runners\\."
    FORMAT     = "forgecicd_pool_idle_runners::$1"
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

resource "splunk_configs_conf" "forgecicd_pool_top_up_cap" {
  name = "transforms/forgecicd_pool_top_up_cap"

  variables = {
    REGEX      = "Capping pool top-up from ([0-9]+) to ([0-9]+) to respect the maximum of ([0-9]+) runners"
    FORMAT     = "forgecicd_pool_cap_from::$1 forgecicd_pool_cap_to::$2 forgecicd_pool_maximum_runners::$3"
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

resource "splunk_configs_conf" "forgecicd_scale_down_runner_instance_id" {
  name = "transforms/forgecicd_scale_down_runner_instance_id"

  variables = {
    REGEX      = "Runner '(i-[0-9a-f]+)'"
    FORMAT     = "forgecicd_runner_instance_id::$1"
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

resource "splunk_configs_conf" "forgecicd_scale_down_aws_runner_instance_id" {
  name = "transforms/forgecicd_scale_down_aws_runner_instance_id"

  variables = {
    REGEX      = "AWS runner instance '(i-[0-9a-f]+)'"
    FORMAT     = "forgecicd_runner_instance_id::$1"
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

resource "splunk_configs_conf" "forgecicd_scale_down_orphan_runner_instance_id" {
  name = "transforms/forgecicd_scale_down_orphan_runner_instance_id"

  variables = {
    REGEX      = "Orphan runner '(i-[0-9a-f]+)'"
    FORMAT     = "forgecicd_runner_instance_id::$1"
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
