mock_provider "aws" {}

variables {
  aws_profile = "test"
  aws_region  = "us-east-1"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
  repositories = [
    {
      repo         = "forge/runner"
      mutability   = "IMMUTABLE"
      scan_on_push = true
    },
    {
      repo         = "forge/tools"
      mutability   = "MUTABLE"
      scan_on_push = false
    },
  ]
}

run "ecr_repository_contract" {
  assert {
    condition = (
      aws_ecr_repository.ops_container_repository["forge/runner"].name == "forge/runner"
      && aws_ecr_repository.ops_container_repository["forge/runner"].image_tag_mutability == "IMMUTABLE"
      && aws_ecr_repository.ops_container_repository["forge/runner"].image_scanning_configuration[0].scan_on_push
    )
    error_message = "ECR helper must preserve immutable scan-on-push repositories when configured."
  }

  assert {
    condition = (
      aws_ecr_repository.ops_container_repository["forge/tools"].name == "forge/tools"
      && aws_ecr_repository.ops_container_repository["forge/tools"].image_tag_mutability == "MUTABLE"
      && aws_ecr_repository.ops_container_repository["forge/tools"].image_scanning_configuration[0].scan_on_push == false
    )
    error_message = "ECR helper must preserve mutable repositories without forcing scan-on-push."
  }

  assert {
    condition = (
      strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/runner"].policy, "Expire untagged images after 28 days")
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/runner"].policy, "\"countNumber\": 180")
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/runner"].policy, "\"*-pre-*\"")
    )
    error_message = "ECR helper lifecycle policy must keep untagged, release, and pre-release cleanup rules."
  }
}

run "rejects_unknown_ecr_mutability" {
  command = plan

  variables {
    repositories = [
      {
        repo         = "forge/bad"
        mutability   = "BROKEN"
        scan_on_push = true
      },
    ]
  }

  expect_failures = [
    var.repositories,
  ]
}
