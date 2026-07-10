mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_region" {
    defaults = {
      description = "US East (N. Virginia)"
      endpoint    = "ec2.us-east-1.amazonaws.com"
      region      = "us-east-1"
    }
  }
}

variables {
  prefix                    = "forge-test"
  logging_retention_in_days = 30
  log_level                 = "INFO"
  github_api                = "https://api.github.com"
  ghes_org                  = "forge"
  runner_group_name         = "forge-runners"
  repository_selection      = "selected"
  tags = {
    Product = "Forge"
    Env     = "test"
  }
  github_app = {
    key_base64_ssm = {
      arn = "arn:aws:ssm:us-east-1:123456789012:parameter/github-app-key"
    }
    id_ssm = {
      arn = "arn:aws:ssm:us-east-1:123456789012:parameter/github-app-id"
    }
    installation_id_ssm = {
      arn = "arn:aws:ssm:us-east-1:123456789012:parameter/github-app-installation-id"
    }
  }
}

run "rejects_unknown_repository_selection" {
  command = plan

  variables {
    repository_selection = "private"
  }

  expect_failures = [
    var.repository_selection,
  ]
}

run "rejects_uppercase_repository_selection" {
  command = plan

  variables {
    repository_selection = "ALL"
  }

  expect_failures = [
    var.repository_selection,
  ]
}
