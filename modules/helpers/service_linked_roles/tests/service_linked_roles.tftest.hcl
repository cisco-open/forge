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
}

run "service_linked_role_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_service_linked_role.spot.aws_service_name == "spot.amazonaws.com"
      && aws_iam_service_linked_role.spot.tags.Product == "Forge"
      && aws_iam_service_linked_role.spot.tags.Env == "test"
    )
    error_message = "Service-linked role helper must keep the Spot service-linked role and merged security tags."
  }
}
