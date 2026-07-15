mock_provider "aws" {}

override_resource {
  target = aws_iam_role.config
  values = {
    arn = "arn:aws:iam::123456789012:role/forge-aws-config-recorder"
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
    user_id    = "AIDATEST"
  }
}

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

override_data {
  target = data.aws_iam_policy_document.config_assume_role
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Principal\":{\"Service\":\"config.amazonaws.com\"}}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.config_delivery_bucket
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:PutObject\",\"Resource\":\"arn:aws:s3:::forge-config-123456789012-us-east-1/*\",\"Principal\":{\"Service\":\"config.amazonaws.com\"}}]}"
  }
}

variables {
  aws_profile          = "test"
  aws_region           = "us-east-1"
  delivery_bucket_name = "forge-config-123456789012-us-east-1"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "aws_config_recording_contract" {
  command = plan

  assert {
    condition = (
      aws_config_configuration_recorder.dedicated_hosts.recording_group[0].all_supported == false
      && toset(aws_config_configuration_recorder.dedicated_hosts.recording_group[0].resource_types) == toset(["AWS::EC2::Host", "AWS::EC2::Instance"])
      && aws_config_configuration_recorder.dedicated_hosts.recording_mode[0].recording_frequency == "CONTINUOUS"
      && aws_config_configuration_recorder_status.dedicated_hosts.is_enabled == true
      && aws_config_delivery_channel.dedicated_hosts.s3_bucket_name == "forge-config-123456789012-us-east-1"
    )
    error_message = "AWS Config must continuously record Dedicated Hosts and EC2 instances and enable the recorder."
  }

}

run "rejects_invalid_delivery_bucket_name" {
  command = plan

  variables {
    delivery_bucket_name = "INVALID_BUCKET"
  }

  expect_failures = [var.delivery_bucket_name]
}
