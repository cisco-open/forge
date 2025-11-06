resource "splunk_configs_conf" "forgecicd_runner_logs_tenant_fields_event" {
  name = "transforms/forgecicd_runner_logs_tenant_fields_event"

  variables = {
    "REGEX"      = "^(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-forge-gh-logs-(?<account_id>\\d+):(?<github_org>[a-zA-Z0-9._-]+)\\/(?<github_repo>[a-zA-Z0-9._-]+)\\/(?<workflow_run>\\d+)\\/(?<attempt>\\d+)\\/(?<job_id>\\d+)\\.json$"
    "FORMAT"     = "forgecicd_tenant::$1 forgecicd_region_alias::$2 forgecicd_vpc_alias::$3 github_org::$5 github_repo::$6 workflow_run::$7 attempt::$8 job_id::$9 forgecicd_log_type::runner-job-event"
    "SOURCE_KEY" = "source"
    "CLEAN_KEYS" = "0"
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

resource "splunk_configs_conf" "forgecicd_runner_logs_tenant_fields_logs" {
  name = "transforms/forgecicd_runner_logs_tenant_fields_logs"

  variables = {
    "REGEX"      = "^(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-forge-gh-logs-(?<account_id>\\d+):(?<github_org>[a-zA-Z0-9._-]+)\\/(?<github_repo>[a-zA-Z0-9._-]+)\\/(?<workflow_run>\\d+)\\/(?<attempt>\\d+)\\/(?<job_id>\\d+)\\.log$"
    "FORMAT"     = "forgecicd_tenant::$1 forgecicd_region_alias::$2 forgecicd_vpc_alias::$3 github_org::$5 github_repo::$6 workflow_run::$7 attempt::$8 job_id::$9 forgecicd_log_type::runner-job-logs"
    "SOURCE_KEY" = "source"
    "CLEAN_KEYS" = "0"
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

resource "splunk_configs_conf" "forgecicd_runner_ec2" {
  name = "transforms/forgecicd_runner_ec2"

  variables = {
    REGEX      = "^(?<forgecicd_instance_id>i-[a-zA-Z0-9]+)$"
    FORMAT     = "forgecicd_type::ec2 forgecicd_instance_id::$1"
    SOURCE_KEY = "runner_name"
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

resource "splunk_configs_conf" "forgecicd_runner_arc" {
  name = "transforms/forgecicd_runner_arc"

  variables = {
    REGEX      = "^(?<forgecicd_instance_id>[a-zA-Z0-9_-]+-[a-z0-9]+-runner-[a-zA-Z0-9]+)$"
    FORMAT     = "forgecicd_type::arc forgecicd_instance_id::$1"
    SOURCE_KEY = "runner_name"
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
