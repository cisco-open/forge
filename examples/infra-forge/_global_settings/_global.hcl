locals {
  # Default region for the AWS accounts associated with the account (i.e. where
  # we store the TF state files, etc.).
  team_name             = "ForgeTeam"
  product_name          = "Forge"
  project_name          = "forge"
  cloud_provider        = "aws"
  sl_aws_account_prefix = "forge-ops" # Prefix for the AWS profile. Eg: forge-ops-<dev> | forge-ops-<prod>.

  # Team information.
  group_email = "<your-team emai>"

  splunk_api_url         = "https://api.<your region>.signalfx.com"
  splunk_organization_id = "<org id>"
}
