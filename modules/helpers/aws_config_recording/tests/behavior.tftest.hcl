mock_provider "aws" {}

override_resource {
  target = aws_servicecatalogappregistry_application.this
  values = {
    application_tag = {
      "awsApplication" = "arn:aws:resource-groups:eu-west-1:123456789012:group/helpers_aws_config_recording_eu-west-1"
    }
  }
}

override_resource {
  target = aws_iam_role.config
  values = {
    arn = "arn:aws:iam::123456789012:role/forge-aws-config-recorder-eu-west-1"
  }
}

override_resource {
  target = aws_s3_bucket.config_delivery
  values = {
    arn = "arn:aws:s3:::123456789012-forge-aws-config-eu-west-1"
    id  = "123456789012-forge-aws-config-eu-west-1"
  }
}

override_resource {
  target = aws_sqs_queue.config_events
  values = {
    arn = "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-eu-west-1"
    url = "https://sqs.eu-west-1.amazonaws.com/123456789012/123456789012-forge-aws-config-events-eu-west-1"
  }
}

override_resource {
  target = aws_sqs_queue.config_events_dlq
  values = {
    arn = "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-dlq-eu-west-1"
    url = "https://sqs.eu-west-1.amazonaws.com/123456789012/123456789012-forge-aws-config-events-dlq-eu-west-1"
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

variables {
  aws_profile = "test"
  aws_region  = "eu-west-1"
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

run "managed_delivery_contract" {
  command = plan

  assert {
    condition = (
      aws_config_configuration_recorder.this.recording_group[0].all_supported == false
      && aws_iam_role.config.name == "forge-aws-config-recorder-eu-west-1"
      && toset(aws_config_configuration_recorder.this.recording_group[0].resource_types) == toset(["AWS::EC2::Instance", "AWS::S3::Bucket"])
      && aws_config_configuration_recorder.this.recording_mode[0].recording_frequency == "CONTINUOUS"
      && aws_config_configuration_recorder_status.this.is_enabled == true
      && aws_config_delivery_channel.this.s3_bucket_name == "123456789012-forge-aws-config-eu-west-1"
    )
    error_message = "AWS Config must continuously record the configured resource types into the managed regional bucket."
  }

  assert {
    condition = (
      aws_s3_bucket.config_delivery[0].bucket == "123456789012-forge-aws-config-eu-west-1"
      && aws_s3_bucket.config_delivery[0].force_destroy == false
      && aws_s3_bucket.config_delivery[0].tags.Product == "Forge"
      && aws_s3_bucket.config_delivery[0].tags.Env == "test"
      && aws_s3_bucket_ownership_controls.config_delivery[0].rule[0].object_ownership == "BucketOwnerPreferred"
      && aws_s3_bucket_versioning.config_delivery[0].versioning_configuration[0].status == "Enabled"
      && one(one(aws_s3_bucket_server_side_encryption_configuration.config_delivery[0].rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
      && aws_s3_bucket_public_access_block.config_delivery[0].block_public_acls == true
      && aws_s3_bucket_public_access_block.config_delivery[0].block_public_policy == true
      && aws_s3_bucket_public_access_block.config_delivery[0].ignore_public_acls == true
      && aws_s3_bucket_public_access_block.config_delivery[0].restrict_public_buckets == true
      && aws_s3_bucket_lifecycle_configuration.config_delivery[0].rule[0].status == "Enabled"
      && aws_s3_bucket_lifecycle_configuration.config_delivery[0].rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
      && length(aws_s3_bucket_policy.config_delivery) == 1
    )
    error_message = "The managed AWS Config bucket must be private, encrypted, versioned, lifecycle-managed, tagged, and protected from destructive removal."
  }

  assert {
    condition = (
      aws_sqs_queue.config_events[0].name == "123456789012-forge-aws-config-events-eu-west-1"
      && aws_sqs_queue.config_events[0].sqs_managed_sse_enabled == true
      && aws_sqs_queue.config_events[0].message_retention_seconds == 1209600
      && aws_sqs_queue.config_events[0].visibility_timeout_seconds == 300
      && jsondecode(aws_sqs_queue.config_events[0].redrive_policy).deadLetterTargetArn == "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-dlq-eu-west-1"
      && jsondecode(aws_sqs_queue.config_events[0].redrive_policy).maxReceiveCount == 5
      && aws_sqs_queue.config_events_dlq[0].name == "123456789012-forge-aws-config-events-dlq-eu-west-1"
      && aws_sqs_queue.config_events_dlq[0].sqs_managed_sse_enabled == true
      && aws_sqs_queue.config_events_dlq[0].message_retention_seconds == 1209600
      && length(aws_sqs_queue_policy.config_events) == 1
      && one(aws_s3_bucket_notification.config_events[0].queue).queue_arn == "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-eu-west-1"
      && toset(one(aws_s3_bucket_notification.config_events[0].queue).events) == toset(["s3:ObjectCreated:*"])
      && one(aws_s3_bucket_notification.config_events[0].queue).filter_prefix == "AWSLogs/123456789012/Config/eu-west-1/"
      && one(aws_s3_bucket_notification.config_events[0].queue).filter_suffix == ".json.gz"
    )
    error_message = "The managed bucket must notify its encrypted SQS queue for regional AWS Config .json.gz object creation events."
  }

  assert {
    condition = (
      output.delivery_bucket_name == "123456789012-forge-aws-config-eu-west-1"
      && output.delivery_bucket_arn == "arn:aws:s3:::123456789012-forge-aws-config-eu-west-1"
      && output.sqs.arn == "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-eu-west-1"
      && output.sqs.dead_letter_queue_arn == "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-dlq-eu-west-1"
      && output.sqs.url == "https://sqs.eu-west-1.amazonaws.com/123456789012/123456789012-forge-aws-config-events-eu-west-1"
      && output.splunk_s3_logs.bucket_arn == "arn:aws:s3:::123456789012-forge-aws-config-eu-west-1"
      && output.splunk_s3_logs.bucket_kms_key_arn == null
      && output.splunk_s3_logs.sqs.arn == "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-eu-west-1"
      && output.splunk_s3_logs.sqs.dead_letter_queue_arn == "arn:aws:sqs:eu-west-1:123456789012:123456789012-forge-aws-config-events-dlq-eu-west-1"
      && output.splunk_s3_logs.sqs.url == "https://sqs.eu-west-1.amazonaws.com/123456789012/123456789012-forge-aws-config-events-eu-west-1"
    )
    error_message = "Managed delivery outputs must expose the bucket, SQS, DLQ, and Splunk Data Manager producer contract."
  }
}

run "uses_external_delivery_bucket" {
  command = plan

  variables {
    delivery_bucket_name = "central-config-bucket-eu-west-1"
  }

  assert {
    condition = (
      aws_config_delivery_channel.this.s3_bucket_name == "central-config-bucket-eu-west-1"
      && output.delivery_bucket_name == "central-config-bucket-eu-west-1"
      && output.delivery_bucket_arn == "arn:aws:s3:::central-config-bucket-eu-west-1"
      && output.sqs == null
      && output.splunk_s3_logs == null
    )
    error_message = "AWS Config must preserve the external delivery bucket contract and expose no managed queue."
  }

  assert {
    condition = (
      length(aws_s3_bucket.config_delivery) == 0
      && length(aws_s3_bucket_ownership_controls.config_delivery) == 0
      && length(aws_s3_bucket_versioning.config_delivery) == 0
      && length(aws_s3_bucket_server_side_encryption_configuration.config_delivery) == 0
      && length(aws_s3_bucket_public_access_block.config_delivery) == 0
      && length(aws_s3_bucket_lifecycle_configuration.config_delivery) == 0
      && length(aws_s3_bucket_policy.config_delivery) == 0
      && length(aws_sqs_queue.config_events_dlq) == 0
      && length(aws_sqs_queue.config_events) == 0
      && length(aws_sqs_queue_policy.config_events) == 0
      && length(aws_s3_bucket_notification.config_events) == 0
    )
    error_message = "External delivery mode must not create or manage S3 or SQS resources."
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
