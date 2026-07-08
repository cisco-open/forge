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

run "creates_spot_service_linked_role" {
  command = plan

  assert {
    condition = (
      aws_iam_service_linked_role.spot.aws_service_name == "spot.amazonaws.com"
      && aws_iam_service_linked_role.spot.tags.Product == "Forge"
      && aws_iam_service_linked_role.spot.tags.Env == "test"
    )
    error_message = "Service-linked roles helper must create the EC2 Spot service-linked role with merged tags."
  }
}
