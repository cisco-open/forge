locals {
  forge = {
    runner_roles = [
      "arn:aws:iam::123456789012:role/tenant_example-euw1-sl-small/tenant_example-euw1-sl-small-runner-role",
      "arn:aws:iam::123456789012:role/tenant_example-euw1-sl-standard/tenant_example-euw1-sl-standard-runner-role",
      "arn:aws:iam::123456789012:role/tenant_example-euw1-sl-large/tenant_example-euw1-sl-large-runner-role",
      "arn:aws:iam::123456789012:role/tenant_example-euw1-sl-dependabot-arc-runner-role",
      "arn:aws:iam::123456789012:role/tenant_example-euw1-sl-k8s-arc-runner-role",
    ]
    ecr_repositories = {
      names = [
        "pre-commit",
        "ops-builder",
        "actions-runner",
      ]
      ecr_access_account_ids = [
        "123456789012", # Accounts that can pull from the ECR repositories
      ]
    }
  }
}
