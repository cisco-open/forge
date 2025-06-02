locals {
  team_name          = "forgeMT" # <REPLACE WITH YOUR VALUE> # e.g., "DevOps Team"
  product_name       = "forgeMT" # <REPLACE WITH YOUR VALUE> # e.g., "Internal Platform"
  project_name       = "forgemt" # <REPLACE WITH YOUR VALUE> # e.g., "intplat"
  aws_account_prefix = "forge"   # <REPLACE WITH YOUR VALUE> # e.g., "intplat-ops"

  # GitHub organization for GitOps repo.
  git_org = "forgemt" # <REPLACE WITH YOUR VALUE> e.g., "my-org"

  # Team information.
  group_email = "forgemt@cisco.com" # <REPLACE WITH YOUR VALUE> e.g., "devops@example.com"
}
