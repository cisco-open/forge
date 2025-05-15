provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias   = "cloudformation_s3_config"
  region  = var.cloudformation_s3_config.region
  profile = var.aws_profile

  # Required, as per security guidelines.
  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias = "by_region"
  # supported by opentofu >= 1.9.0
  for_each = toset(
    distinct(merge(
      var.security_metadata_config.enabled ? { security_metadata = var.security_metadata_config.regions } : {},
      var.cloudwatch_log_groups_config.enabled ? { cloudwatch_logs = var.cloudwatch_log_groups_config.regions } : {},
      var.custom_cloudwatch_log_groups_config.enabled ? { custom_cloudwatch_logs = [for v in var.custom_cloudwatch_log_groups_config.log_group_name_prefixes : v.region] } : {}
      ) != {} ? flatten(values(merge(
        var.security_metadata_config.enabled ? { security_metadata = var.security_metadata_config.regions } : {},
        var.cloudwatch_log_groups_config.enabled ? { cloudwatch_logs = var.cloudwatch_log_groups_config.regions } : {},
        var.custom_cloudwatch_log_groups_config.enabled ? { custom_cloudwatch_logs = [for v in var.custom_cloudwatch_log_groups_config.log_group_name_prefixes : v.region] } : {}
    ))) : [var.aws_region])
  )
  profile = var.aws_profile
  region  = each.key

  default_tags {
    tags = var.tags
  }
}
