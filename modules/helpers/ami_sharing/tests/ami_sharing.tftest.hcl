mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  aws_profile = "test"
  aws_region  = "us-east-1"
  default_tags = {
    Product = "Forge"
  }
  ami_name_filters = [
    "forge-runner-linux-*",
    "forge-runner-windows-*",
  ]
  account_ids = [
    "111111111111",
    "222222222222",
  ]
}

run "ami_sharing_account_fanout_contract" {
  command = plan

  assert {
    condition = (
      length(aws_ami_launch_permission.share_amis) == 2
      && aws_ami_launch_permission.share_amis["ami-0123456789abcdef0-111111111111"].image_id == "ami-0123456789abcdef0"
      && aws_ami_launch_permission.share_amis["ami-0123456789abcdef0-111111111111"].account_id == "111111111111"
      && aws_ami_launch_permission.share_amis["ami-0123456789abcdef0-222222222222"].image_id == "ami-0123456789abcdef0"
      && aws_ami_launch_permission.share_amis["ami-0123456789abcdef0-222222222222"].account_id == "222222222222"
    )
    error_message = "AMI sharing must deduplicate selected AMI IDs and grant launch permission to every configured account."
  }
}

run "empty_account_list_creates_no_permissions" {
  command = plan

  variables {
    account_ids = []
  }

  assert {
    condition     = length(aws_ami_launch_permission.share_amis) == 0
    error_message = "AMI sharing must not create launch permissions when no target accounts are configured."
  }
}
