locals {
  env_data = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))

  splunk_cloud = "https://<your instance>.splunkcloud.com"
  cloudformation_s3_config = {
    bucket = "${local.env_data.locals.aws_account_id}-short-term-storage"
    key    = "cicd_artifacts/cf-templates/"
    region = "eu-west-1"
  }

  cloudwatch_log_groups_config = {
    enabled = true
    name    = "forge-cwl-prod"
    datasource = {
      cwl-eks = {
        enabled = true
        index   = "forge-prod-index"
      }
      cwl-lambda = {
        enabled = true
        index   = "forge-prod-index"
      }
    }
    regions = ["eu-west-1"]
  }

  security_metadata_config = {
    enabled = true
    name    = "forge-secmeta-prod"
    datasource = {
      metadata = {
        enabled = true
        index   = "forge-prod-index"
      }
    }
    regions = ["eu-west-1"]
  }

}
