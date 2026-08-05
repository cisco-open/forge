mock_provider "aws" {}

override_resource {
  target = aws_iam_role.config
  values = {
    arn = "arn:aws:iam::123456789012:role/forge-aws-config-recorder-eu-west-1"
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

variables {
  aws_profile          = "test"
  aws_region           = "eu-west-1"
  delivery_bucket_name = "forge-config-123456789012-eu-west-1"
  recorded_resource_types = [
    "AWS::EC2::Instance",
    "AWS::S3::Bucket",
  ]
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
      aws_config_configuration_recorder.this.recording_group[0].all_supported == false
      && aws_iam_role.config.name == "forge-aws-config-recorder-eu-west-1"
      && toset(aws_config_configuration_recorder.this.recording_group[0].resource_types) == toset(["AWS::EC2::Instance", "AWS::S3::Bucket"])
      && aws_config_configuration_recorder.this.recording_mode[0].recording_frequency == "CONTINUOUS"
      && aws_config_configuration_recorder_status.this.is_enabled == true
      && aws_config_delivery_channel.this.s3_bucket_name == "forge-config-123456789012-eu-west-1"
    )
    error_message = "AWS Config must continuously record the configured resource types and enable the recorder."
  }

}

run "uses_input_delivery_bucket" {
  command = plan

  variables {
    delivery_bucket_name = "central-config-bucket-eu-west-1"
  }

  assert {
    condition     = aws_config_delivery_channel.this.s3_bucket_name == "central-config-bucket-eu-west-1"
    error_message = "AWS Config must use the input delivery bucket without creating or managing S3 resources."
  }
}

run "rejects_empty_recorded_resource_types" {
  command = plan

  variables {
    recorded_resource_types = []
  }

  expect_failures = [var.recorded_resource_types]
}

run "rejects_invalid_delivery_bucket_name" {
  command = plan

  variables {
    delivery_bucket_name = "INVALID_BUCKET"
  }

  expect_failures = [var.delivery_bucket_name]
}
