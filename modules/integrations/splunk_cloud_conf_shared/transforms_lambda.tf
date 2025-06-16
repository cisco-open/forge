resource "splunk_configs_conf" "forgecicd_extra_lambda_tenant_fields" {
  name = "transforms/forgecicd_extra_lambda_tenant_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):\\/aws\\/lambda\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_log_type>github-app-runner-group|github-clean-global-lock)"
    "FORMAT"     = "aws_region::$1 forgecicd_tenant::$2 forgecicd_region_alias::$3 forgecicd_vpc_alias::$4 forgecicd_log_type::$5"
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
