mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  repository_names       = ["forge-base", "forge-runner"]
  ecr_access_account_ids = ["111111111111", "222222222222"]
}

run "creates_policy_for_each_repository" {
  command = plan

  assert {
    condition = (
      length(aws_ecr_repository_policy.repository_policy) == 2
      && aws_ecr_repository_policy.repository_policy["forge-base"].repository == "forge-base"
      && aws_ecr_repository_policy.repository_policy["forge-runner"].repository == "forge-runner"
      && aws_ecr_repository_policy.repository_policy["forge-base"].policy == "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    )
    error_message = "ECR repository policy helper must create one policy per repository with the generated policy document."
  }

  assert {
    condition = (
      output.repository_policy_count == 2
      && contains(output.repository_policy_names, "forge-base")
      && contains(output.repository_policy_names, "forge-runner")
    )
    error_message = "ECR repository policy helper outputs must expose the policy count and repository names."
  }
}

run "empty_repository_list_creates_no_policies" {
  command = plan

  variables {
    repository_names = []
  }

  assert {
    condition = (
      length(aws_ecr_repository_policy.repository_policy) == 0
      && output.repository_policy_count == 0
      && length(output.repository_policy_names) == 0
    )
    error_message = "ECR repository policy helper must not create policies when no repositories are configured."
  }
}
