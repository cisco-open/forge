locals {
  forge = {
    # <REPLACE WITH YOUR VALUE>
    runner_roles = [
      "arn:aws:iam::123456789012:role/srea-euw1-sl-small/srea-euw1-sl-small-runner-role",
      "arn:aws:iam::123456789012:role/srea-euw1-sl-standard/srea-euw1-sl-standard-runner-role",
      "arn:aws:iam::123456789012:role/srea-euw1-sl-large/srea-euw1-sl-large-runner-role",
      "arn:aws:iam::123456789012:role/srea-euw1-sl-dependabot-arc-runner-role",
      "arn:aws:iam::123456789012:role/srea-euw1-sl-k8s-arc-runner-role",
    ]
    # <REPLACE WITH YOUR VALUE>
    ecr_repositories = {
      names = [
        "pre-commit",
        "ops-builder",
        "actions-runner",
        "actions-runner-base-image",
      ]
      # <REPLACE WITH YOUR VALUE>
      ecr_access_account_ids = [
        "123456789013",
      ]
      # <REPLACE WITH YOUR VALUE>
      regions = [
        "eu-west-1",
      ]
    }
  }
}
