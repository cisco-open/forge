resource "splunk_configs_conf" "forgecicd_billing_cur_instance_id" {
  name = "transforms/forgecicd_billing_cur_instance_id"

  variables = {
    REGEX      = "\"resource_id\"\\s*:\\s*\"(?<forgecicd_instance_id>i-[a-f0-9]+)\""
    FORMAT     = "forgecicd_instance_id::$1"
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

resource "splunk_configs_conf" "forgecicd_billing_cur_volume_id" {
  name = "transforms/forgecicd_billing_cur_volume_id"

  variables = {
    REGEX      = "\"resource_id\"\\s*:\\s*\"(?<forgecicd_volume_id>vol-[a-f0-9]+)\""
    FORMAT     = "forgecicd_volume_id::$1"
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
