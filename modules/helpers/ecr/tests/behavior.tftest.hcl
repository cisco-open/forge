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
      repo         = "forge/actions-runner"
      mutability   = "IMMUTABLE"
      scan_on_push = true
    },
    {
      repo         = "forge/bootstrap"
      mutability   = "MUTABLE"
      scan_on_push = false
    },
  ]
}

run "ecr_repository_lifecycle_contract" {
  command = plan

  assert {
    condition = (
      aws_ecr_repository.ops_container_repository["forge/actions-runner"].name == "forge/actions-runner"
      && aws_ecr_repository.ops_container_repository["forge/actions-runner"].image_tag_mutability == "IMMUTABLE"
      && aws_ecr_repository.ops_container_repository["forge/actions-runner"].image_scanning_configuration[0].scan_on_push == true
      && aws_ecr_repository.ops_container_repository["forge/actions-runner"].tags.Product == "Forge"
      && aws_ecr_repository.ops_container_repository["forge/actions-runner"].tags.Env == "test"
      && aws_ecr_repository.ops_container_repository["forge/bootstrap"].image_tag_mutability == "MUTABLE"
      && aws_ecr_repository.ops_container_repository["forge/bootstrap"].image_scanning_configuration[0].scan_on_push == false
      && contains(output.ops_container_repository_names, "forge/actions-runner")
      && contains(output.ops_container_repository_names, "forge/bootstrap")
    )
    error_message = "ECR helper must create repositories from inputs, preserve mutability/scanning settings, merge tags, and expose repository names."
  }

  assert {
    condition = (
      aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/actions-runner"].repository == "forge/actions-runner"
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/actions-runner"].policy, "Expire untagged images after 28 days")
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/actions-runner"].policy, "\"countNumber\": 28")
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/actions-runner"].policy, "\"countNumber\": 180")
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/actions-runner"].policy, "\"countNumber\": 2")
      && strcontains(aws_ecr_lifecycle_policy.ops_cleanup_policy["forge/actions-runner"].policy, "*-pre-*")
    )
    error_message = "ECR helper must keep untagged, versioned, and prerelease lifecycle cleanup rules."
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
