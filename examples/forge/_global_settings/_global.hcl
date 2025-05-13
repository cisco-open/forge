locals {
  # Default region for the AWS accounts associated with the account (i.e. where
  # we store the TF state files, etc.).
  team_name             = "ForgeTeam"
  product_name          = "Forge"
  project_name          = "forge"
  cloud_provider        = "aws"
  sl_aws_account_prefix = "forge-ops" # Prefix for the AWS profile. Eg: forge-ops-<dev> | forge-ops-<prod>.

  # GitHub organization.
  git_org = "<your-github-org>"

  splunk_cloud_extractions = {
    acl = {
      app     = "search_app_forge"
      owner   = "forge-generic-user"
      sharing = "global"
      read    = ["*"]
      write   = ["forge-generic-user-role"]
    }
  }
}
