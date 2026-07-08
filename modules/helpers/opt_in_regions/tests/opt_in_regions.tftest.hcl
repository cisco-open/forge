mock_provider "aws" {}

variables {
  aws_profile = "test"
  aws_region  = "us-east-1"
  default_tags = {
    Product = "Forge"
  }
  opt_in_regions = ["ap-east-1", "me-south-1"]
}

run "enables_each_configured_region" {
  command = plan

  assert {
    condition = (
      length(aws_account_region.enabled_regions) == 2
      && aws_account_region.enabled_regions["ap-east-1"].region_name == "ap-east-1"
      && aws_account_region.enabled_regions["ap-east-1"].enabled
      && aws_account_region.enabled_regions["me-south-1"].region_name == "me-south-1"
      && aws_account_region.enabled_regions["me-south-1"].enabled
    )
    error_message = "Opt-in region helper must enable every configured region by name."
  }
}

run "empty_region_list_is_noop" {
  command = plan

  variables {
    opt_in_regions = []
  }

  assert {
    condition     = length(aws_account_region.enabled_regions) == 0
    error_message = "Opt-in region helper must not create region resources when no regions are configured."
  }
}
