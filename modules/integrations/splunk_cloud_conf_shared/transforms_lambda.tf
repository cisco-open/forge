resource "splunk_configs_conf" "forgecicd_extra_lambda_tenant_fields" {
  name = "transforms/forgecicd_extra_lambda_tenant_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):\\/aws\\/lambda\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_log_type>register-github-app-runner-group|github-webhook-relay|clean-global-lock|job-log-archiver|job-log-dispatcher|forge-trust-validator)"
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

resource "splunk_configs_conf" "forgecicd_extra_lambda_ec2_tenant_fields" {
  name = "transforms/forgecicd_extra_lambda_ec2_tenant_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):\\/aws\\/lambda\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_log_type>ec2-redrive-deadletter|ec2-update-runner-ssm-ami|ec2-update-runner-tags)"
    "FORMAT"     = "aws_region::$1 forgecicd_tenant::$2 forgecicd_region_alias::$3 forgecicd_vpc_alias::$4 forgecicd_log_type::$5 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_trust_validation" {
  name = "transforms/forgecicd_trust_validation"

  variables = {
    REGEX      = "Validation complete:\\s*(\\[[^\\r\\n]+])"
    FORMAT     = "forgecicd_trust_validation::$1"
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
