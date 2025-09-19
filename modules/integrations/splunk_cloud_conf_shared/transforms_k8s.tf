resource "splunk_configs_conf" "forgecicd_kube_container_runner_tenant_fields" {
  name = "transforms/forgecicd_kube_container_runner_tenant_fields"

  variables = {
    "REGEX"      = "\\/var\\/log\\/pods\\/(?<forgecicd_tenant>[a-z0-9]+)_(?<forgecicd_instance_id>(?<forgecicd_runner_type>[a-z0-9]+)-[a-z0-9-]+(?:_[0-9a-f-]+)?)\\/(?<forgecicd_log_type>[a-z0-9-]+)\\/\\d+\\.log"
    "FORMAT"     = "forgecicd_tenant::$1 forgecicd_instance_id::$2 forgecicd_runner_type::$3 forgecicd_type::arc"
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

resource "splunk_configs_conf" "forgecicd_kube_container_listener_tenant_fields" {
  name = "transforms/forgecicd_kube_container_listener_tenant_fields"

  variables = {
    "REGEX"      = "\\/var\\/log\\/pods\\/(?<forgecicd_tenant>[a-z0-9]+)_(?<forgecicd_runner_type>[a-z0-9]+)-[a-z0-9]+-(?<forgecicd_log_type>listener)"
    "FORMAT"     = "forgecicd_tenant::$1 forgecicd_instance_id::$2 forgecicd_runner_type::$3 forgecicd_type::arc"
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

resource "splunk_configs_conf" "forgecicd_kube_container_manager_tenant_fields" {
  name = "transforms/forgecicd_kube_container_manager_tenant_fields"

  variables = {
    "REGEX"      = "\\/var\\/log\\/pods\\/[a-z0-9]+_(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_log_type>gha-rs-controller)"
    "FORMAT"     = "forgecicd_tenant::$1 forgecicd_instance_id::$2 forgecicd_runner_type::$3 forgecicd_type::arc"
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

resource "splunk_configs_conf" "forgecicd_kube_container_runner_ci_result" {
  name = "transforms/forgecicd_kube_container_runner_ci_result"

  variables = {
    "REGEX"      = "WRITE LINE: \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}Z: Job (?P<job_name>[^>]+) completed with result: (?P<ci_result>[^>]+)$"
    "FORMAT"     = "job_name::$1 ci_result::$2 forgecicd_type::arc"
    "SOURCE_KEY" = "_raw"
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

resource "splunk_configs_conf" "forgecicd_kube_container_runner_gh_runner_version" {
  name = "transforms/forgecicd_kube_container_runner_gh_runner_version"

  variables = {
    "REGEX"      = "Current runner version: '(?P<gh_runner_version>[^']+)$"
    "FORMAT"     = "gh_runner_version::$1 forgecicd_type::arc"
    "SOURCE_KEY" = "_raw"
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
