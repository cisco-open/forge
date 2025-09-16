resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_runner_tenant_fields" {
  name = "transforms/forgecicd_cloudwatchlogs_runner_tenant_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):/github-self-hosted-runners/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_runner_type>[a-z0-9-]+)/([a-z0-9-_]+):(?<forgecicd_instance_id>i-[a-f0-9]+)/(?<forgecicd_log_type>[a-z0-9_-]+)"
    "FORMAT"     = "aws_region::$1 forgecicd_tenant::$2 forgecicd_region_alias::$3 forgecicd_vpc_alias::$4 forgecicd_runner_type::$5 forgecicd_instance_id::$7 forgecicd_log_type::$8 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_runner_pages_github_repo_name" {
  name = "transforms/forgecicd_cloudwatchlogs_runner_pages_github_repo_name"

  variables = {
    "REGEX"      = "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]+Z Working directory is '(?:\\/opt\\/actions-runner\\/_work|\\/__w)\\/(?<repo>[^\\/]+)\\/.*"
    "FORMAT"     = "<github_repo_name>::$2 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_extract_log_time_message" {
  name = "transforms/forgecicd_cloudwatchlogs_extract_log_time_message"

  variables = {
    "REGEX"      = "(?P<log_time>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]+Z)\\s+(?P<message>.+)"
    "FORMAT"     = "log_time::$1 message::$2 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_global_lambda_tenant_fields" {
  name = "transforms/forgecicd_cloudwatchlogs_global_lambda_tenant_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):\\/aws\\/lambda\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_log_type>webhook|dispatch-to-runner)"
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

resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_lambda_tenant_fields" {
  name = "transforms/forgecicd_cloudwatchlogs_lambda_tenant_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):\\/aws\\/lambda\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_runner_type>[a-z0-9-]+)-(?<forgecicd_log_type>scale-down|scale-up|pool)"
    "FORMAT"     = "aws_region::$1 forgecicd_tenant::$2 forgecicd_region_alias::$3 forgecicd_vpc_alias::$4 forgecicd_runner_type::$5 forgecicd_log_type::$6 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_metadata_tenant_fields" {
  name = "transforms/forgecicd_metadata_tenant_fields"

  variables = {
    "REGEX"      = "(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-(?<forgecicd_runner_type>[a-z0-9-]+)-action-runner"
    "FORMAT"     = "forgecicd_tenant::$1 forgecicd_region_alias::$2 forgecicd_vpc_alias::$3 forgecicd_runner_type::$4 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_metadata_instance_id" {
  name = "transforms/forgecicd_metadata_instance_id"

  variables = {
    "REGEX"      = "\"InstanceId\"\\s*:\\s*\"(?<forgecicd_instance_id>i-[a-z0-9]+)\""
    "FORMAT"     = "forgecicd_instance_id::$1 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_metadata_image_id" {
  name = "transforms/forgecicd_metadata_image_id"

  variables = {
    "REGEX"      = "\"ImageId\"\\s*:\\s*\"(?<forgecicd_image_id>ami-[a-z0-9]+)\""
    "FORMAT"     = "forgecicd_image_id::$1 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_metadata_instance_type" {
  name = "transforms/forgecicd_metadata_instance_type"

  variables = {
    "REGEX"      = "\"InstanceType\"\\s*:\\s*\"(?<forgecicd_instance_type>[a-z0-9\\.]+)\""
    "FORMAT"     = "forgecicd_instance_type::$1 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_runner_ci_result" {
  name = "transforms/forgecicd_cloudwatchlogs_runner_ci_result"

  variables = {
    "REGEX"      = "WRITE LINE: \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}Z: Job (?P<job_name>[^>]+) completed with result: (?P<ci_result>[^>]+)$"
    "FORMAT"     = "job_name::$1 ci_result::$2 forgecicd_type::ec2"
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

resource "splunk_configs_conf" "forgecicd_cloudwatchlogs_runner_gh_runner_version" {
  name = "transforms/forgecicd_cloudwatchlogs_runner_gh_runner_version"

  variables = {
    "REGEX"      = "Current runner version: '(?P<gh_runner_version>[^']+)$"
    "FORMAT"     = "gh_runner_version::$1 forgecicd_type::ec2"
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
