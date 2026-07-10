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
  ]
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

run "rejects_lowercase_ecr_mutability" {
  command = plan

  variables {
    repositories = [
      {
        repo         = "forge/lowercase"
        mutability   = "mutable"
        scan_on_push = true
      },
    ]
  }

  expect_failures = [
    var.repositories,
  ]
}
