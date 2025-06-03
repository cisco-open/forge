locals {
  env_data = read_terragrunt_config(find_in_parent_folders("_environment_wide_settings/_environment.hcl"))

  splunk_cloud = "https://mycompany.splunkcloud.com" # <REPLACE WITH YOUR VALUE>
  cloudformation_s3_config = {
    bucket = "${local.env_data.locals.aws_account_id}-short-term-storage" # <REPLACE WITH YOUR VALUE>
    key    = "cicd_artifacts/cf-templates/"                               # <REPLACE WITH YOUR VALUE>
    region = "eu-west-1"                                                  # <REPLACE WITH YOUR VALUE>
  }

  cloudwatch_log_groups_config = {
    enabled = true
    name    = "forge-cwl-prod" # <REPLACE WITH YOUR VALUE>
    datasource = {
      cwl-eks = {
        enabled = true
        index   = "forge-prod-index" # <REPLACE WITH YOUR VALUE>
      }
      cwl-lambda = {
        enabled = true
        index   = "forge-prod-index" # <REPLACE WITH YOUR VALUE>
      }
    }
    regions = ["eu-west-1"] # <REPLACE WITH YOUR VALUE>
  }

  security_metadata_config = {
    enabled = true
    name    = "forge-secmeta-prod" # <REPLACE WITH YOUR VALUE>
    datasource = {
      metadata = {
        enabled = true
        index   = "forge-prod-index" # <REPLACE WITH YOUR VALUE>
      }
    }
    regions = ["eu-west-1"] # <REPLACE WITH YOUR VALUE>
  }

}
