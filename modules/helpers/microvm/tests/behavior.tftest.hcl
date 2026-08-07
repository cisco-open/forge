mock_provider "aws" {}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
    user_id    = "test"
  }
}

override_data {
  target = data.aws_partition.current
  values = {
    dns_suffix         = "amazonaws.com"
    id                 = "aws"
    partition          = "aws"
    reverse_dns_prefix = "com.amazonaws"
  }
}

override_data {
  target = data.aws_subnet.selected
  values = {
    vpc_id = "vpc-0123456789abcdef0"
  }
}

override_data {
  target = data.aws_iam_policy_document.lambda_service_assume_role
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":[\"sts:AssumeRole\",\"sts:TagSession\"]}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.lambda_assume_operator_role
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.artifact_bucket
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Action\":\"s3:*\",\"Resource\":\"arn:aws:s3:::forge-microvm-test-eu-west-1\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.build
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::forge-microvm-test-eu-west-1/lambda-microvms/*\"}]}"
  }
}

override_data {
  target = data.aws_iam_policy_document.usage
  values = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"lambda:RunMicrovm\",\"lambda:PassNetworkConnector\"],\"Resource\":\"*\"}]}"
  }
}

override_resource {
  target = aws_servicecatalogappregistry_application.this
  values = {
    application_tag = {
      awsApplication = "arn:aws:servicecatalog:eu-west-1:123456789012:/applications/test"
    }
    arn = "arn:aws:servicecatalog:eu-west-1:123456789012:/applications/test"
  }
}

override_resource {
  target = aws_s3_bucket.artifacts
  values = {
    arn = "arn:aws:s3:::forge-microvm-test-eu-west-1"
    id  = "forge-microvm-test-eu-west-1"
  }
}

override_resource {
  target = aws_iam_role.build
  values = {
    arn = "arn:aws:iam::123456789012:role/forge-microvm-build-eu-west-1"
    id  = "forge-microvm-build-eu-west-1"
  }
}

override_resource {
  target = aws_iam_policy.build
  values = {
    arn = "arn:aws:iam::123456789012:policy/forge-microvm-build-eu-west-1"
  }
}

override_resource {
  target = aws_iam_policy.usage
  values = {
    arn = "arn:aws:iam::123456789012:policy/forge-microvm-runtime-usage-eu-west-1"
  }
}

override_resource {
  target = aws_security_group.connector
  values = {
    arn = "arn:aws:ec2:eu-west-1:123456789012:security-group/sg-0123456789abcdef0"
    id  = "sg-0123456789abcdef0"
  }
}

override_resource {
  target = aws_iam_role.operator
  values = {
    arn = "arn:aws:iam::123456789012:role/forge-microvm-network-operator-eu-west-1"
    id  = "forge-microvm-network-operator-eu-west-1"
  }
}

override_resource {
  target = aws_cloudformation_stack.connector
  values = {
    outputs = {
      ConnectorArn   = "arn:aws:lambda:eu-west-1:123456789012:network-connector:nc-22222222-2222-2222-2222-222222222222"
      ConnectorState = "ACTIVE"
    }
  }
}

variables {
  aws_profile             = "test"
  aws_region              = "eu-west-1"
  artifact_bucket_name    = "forge-microvm-test-eu-west-1"
  artifact_retention_days = 45
  image_name_prefix       = "srea-gh-runner-ubuntu-arm64"
  network_connectors = {
    cicd = {
      name       = "srea_gh_runner_egress"
      vpc_id     = "vpc-0123456789abcdef0"
      subnet_ids = ["subnet-0123456789abcdef0"]
    }
    private = {
      name             = "srea-gh-runner-private"
      vpc_id           = "vpc-0123456789abcdef0"
      subnet_ids       = ["subnet-0aaaaaaaaaaaaaaaa"]
      network_protocol = "DualStack"
    }
  }
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
  ecr_repository_arns = [
    "arn:aws:ecr:eu-west-1:123456789012:repository/actions-runner-base-image",
  ]
}

run "regional_microvm_foundation_contract" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket.artifacts.bucket == "forge-microvm-test-eu-west-1"
      && aws_s3_bucket.artifacts.tags.Product == "Forge"
      && aws_s3_bucket.artifacts.tags.Env == "test"
      && aws_s3_bucket_ownership_controls.artifacts.rule[0].object_ownership == "BucketOwnerEnforced"
      && aws_s3_bucket_versioning.artifacts.versioning_configuration[0].status == "Enabled"
      && one(one(aws_s3_bucket_server_side_encryption_configuration.artifacts.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
      && aws_s3_bucket_public_access_block.artifacts.block_public_acls == true
      && aws_s3_bucket_public_access_block.artifacts.block_public_policy == true
      && aws_s3_bucket_public_access_block.artifacts.ignore_public_acls == true
      && aws_s3_bucket_public_access_block.artifacts.restrict_public_buckets == true
      && aws_s3_bucket_public_access_block.artifacts.skip_destroy == true
      && length(aws_s3_bucket_lifecycle_configuration.artifacts.rule[0].filter) == 1
      && aws_s3_bucket_lifecycle_configuration.artifacts.rule[0].expiration[0].days == 45
      && aws_s3_bucket_lifecycle_configuration.artifacts.rule[0].noncurrent_version_expiration[0].noncurrent_days == 45
      && aws_s3_bucket_lifecycle_configuration.artifacts.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    )
    error_message = "MicroVM helper must keep its regional artifact bucket encrypted, versioned, private, tagged, and lifecycle-managed."
  }

  assert {
    condition = (
      aws_iam_role.build.name == "forge-microvm-build-eu-west-1"
      && strcontains(aws_iam_role.build.assume_role_policy, "lambda.amazonaws.com")
      && strcontains(aws_iam_role.build.assume_role_policy, "sts:TagSession")
      && aws_iam_role_policy_attachment.build.role == "forge-microvm-build-eu-west-1"
      && aws_iam_policy.usage.name == "forge-microvm-runtime-usage-eu-west-1"
    )
    error_message = "MicroVM helper must create the Lambda-only build role and expose the unattached regional runtime-usage policy."
  }

  assert {
    condition = (
      output.artifact_bucket_name == "forge-microvm-test-eu-west-1"
      && output.artifact_bucket_arn == "arn:aws:s3:::forge-microvm-test-eu-west-1"
      && output.artifact_prefix == "lambda-microvms"
      && output.build_role_arn == "arn:aws:iam::123456789012:role/forge-microvm-build-eu-west-1"
      && output.usage_policy_arn == "arn:aws:iam::123456789012:policy/forge-microvm-runtime-usage-eu-west-1"
      && output.appregistry_application_arn == "arn:aws:servicecatalog:eu-west-1:123456789012:/applications/test"
    )
    error_message = "MicroVM helper must expose regional build, usage-policy, and AppRegistry outputs without owning publisher IAM or image inventory."
  }

  assert {
    condition = (
      local.image_arn_pattern == "arn:aws:lambda:eu-west-1:123456789012:microvm-image:srea-gh-runner-ubuntu-arm64-*"
      && local.log_group_arn_pattern == "arn:aws:logs:eu-west-1:123456789012:log-group:/aws/lambda/microvms/srea-gh-runner-ubuntu-arm64-*"
      && local.log_stream_arn_pattern == "arn:aws:logs:eu-west-1:123456789012:log-group:/aws/lambda/microvms/srea-gh-runner-ubuntu-arm64-*:log-stream:*"
    )
    error_message = "The image prefix must reserve one image and build-log IAM namespace without enumerating publisher-owned images."
  }

  assert {
    condition = (
      length(regexall("(?s)sid\\s*=\\s*\"ReadRegionalBuildArtifact\".*?resources\\s*=\\s*\\[\"\\$\\{aws_s3_bucket\\.artifacts\\.arn\\}/\\$\\{local\\.artifact_prefix\\}/\\*\"\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"CreateMicrovmBuildLogGroups\".*?resources\\s*=\\s*\\[local\\.log_group_arn_pattern\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"WriteMicrovmBuildLogs\".*?resources\\s*=\\s*\\[local\\.log_stream_arn_pattern\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"UseConfiguredMicrovmImages\".*?resources\\s*=\\s*\\[local\\.image_arn_pattern\\]", file("${path.module}/policies.tf"))) == 1
      && length(regexall("resource\\s+\"aws_cloudwatch_log_group\"", join("\n", [for source_file in fileset(path.module, "*.tf") : file("${path.module}/${source_file}")]))) == 0
      && length(regexall("(data\\s+\"aws_iam_policy_document\"|resource\\s+\"aws_iam_policy\")\\s+\"image_management\"", join("\n", [for source_file in fileset(path.module, "*.tf") : file("${path.module}/${source_file}")]))) == 0
      && length(regexall("resource\\s+\"aws_iam_role_policy_attachment\"\\s+\"publisher\"", join("\n", [for source_file in fileset(path.module, "*.tf") : file("${path.module}/${source_file}")]))) == 0
    )
    error_message = "The helper must provide scoped build, log, and runtime IAM without a log-group resource or publisher image-management policy."
  }
}

run "rejects_invalid_image_name_prefix" {
  command = plan

  variables {
    image_name_prefix = "not/a/microvm/image"
  }

  expect_failures = [var.image_name_prefix]
}

run "rejects_image_namespace_without_suffix_capacity" {
  command = plan

  variables {
    image_name_prefix = join("", [for _ in range(63) : "a"])
  }

  expect_failures = [var.image_name_prefix]
}

run "multiple_network_connector_contract" {
  command = plan

  assert {
    condition = (
      length(aws_security_group.connector) == 2
      && aws_security_group.connector["cicd"].name == "forge-microvm-srea_gh_runner_egress-eu-west-1"
      && aws_security_group.connector["cicd"].vpc_id == "vpc-0123456789abcdef0"
      && aws_security_group.connector["private"].vpc_id == "vpc-0123456789abcdef0"
      && length(aws_security_group.connector["cicd"].ingress) == 0
      && length(aws_security_group.connector["private"].ingress) == 0
      && length(aws_vpc_security_group_egress_rule.ipv4) == 2
      && length(aws_vpc_security_group_egress_rule.ipv6) == 1
      && contains(keys(aws_vpc_security_group_egress_rule.ipv6), "private")
    )
    error_message = "Each connector must have a no-ingress security group in its own VPC and protocol-specific egress."
  }

  assert {
    condition = (
      aws_iam_role.operator.name == "forge-microvm-network-operator-eu-west-1"
      && strcontains(aws_iam_role.operator.assume_role_policy, "lambda.amazonaws.com")
      && strcontains(aws_iam_role.operator.assume_role_policy, "sts:AssumeRole")
      && !strcontains(aws_iam_role.operator.assume_role_policy, "sts:TagSession")
      && !strcontains(aws_iam_role.operator.assume_role_policy, "aws:SourceAccount")
      && aws_iam_role_policy_attachment.operator.role == "forge-microvm-network-operator-eu-west-1"
      && aws_iam_role_policy_attachment.operator.policy_arn == "arn:aws:iam::aws:policy/AWSLambdaNetworkConnectorOperatorPolicy"
      && aws_iam_policy.usage.name == "forge-microvm-runtime-usage-eu-west-1"
    )
    error_message = "Every connector must share one regional Lambda-trusted operator role with the AWS-managed Network Connector policy."
  }

  assert {
    condition = (
      length(aws_cloudformation_stack.connector) == 2
      && !strcontains(aws_cloudformation_stack.connector["cicd"].name, "_")
      && length(aws_cloudformation_stack.connector["cicd"].name) <= 128
      && aws_cloudformation_stack.connector["cicd"].name == local.connector_stack_names["cicd"]
      && endswith(aws_cloudformation_stack.connector["cicd"].name, substr(sha1("cicd"), 0, 8))
      && jsondecode(aws_cloudformation_stack.connector["cicd"].template_body).Resources.Connector.Properties.Name == "srea_gh_runner_egress"
      && jsondecode(aws_cloudformation_stack.connector["cicd"].template_body).Resources.Connector.Properties.OperatorRole == aws_iam_role.operator.arn
      && jsondecode(aws_cloudformation_stack.connector["cicd"].template_body).Resources.Connector.Properties.Configuration.VpcEgressConfiguration.SubnetIds == ["subnet-0123456789abcdef0"]
      && jsondecode(aws_cloudformation_stack.connector["cicd"].template_body).Resources.Connector.Properties.Configuration.VpcEgressConfiguration.NetworkProtocol == "IPv4"
      && jsondecode(aws_cloudformation_stack.connector["private"].template_body).Resources.Connector.Properties.Name == "srea-gh-runner-private"
      && jsondecode(aws_cloudformation_stack.connector["private"].template_body).Resources.Connector.Properties.OperatorRole == aws_iam_role.operator.arn
      && jsondecode(aws_cloudformation_stack.connector["private"].template_body).Resources.Connector.Properties.Configuration.VpcEgressConfiguration.SubnetIds == ["subnet-0aaaaaaaaaaaaaaaa"]
      && jsondecode(aws_cloudformation_stack.connector["private"].template_body).Resources.Connector.Properties.Configuration.VpcEgressConfiguration.NetworkProtocol == "DualStack"
      && jsondecode(aws_cloudformation_stack.connector["private"].template_body).Resources.Connector.Properties.Configuration.VpcEgressConfiguration.AssociatedComputeResourceTypes == ["MicroVm"]
    )
    error_message = "Each map entry must render an independent MicroVm Network Connector with a valid stable stack name."
  }

  assert {
    condition = (
      output.connector_arns["cicd"] == "arn:aws:lambda:eu-west-1:123456789012:network-connector:nc-22222222-2222-2222-2222-222222222222"
      && output.connector_arns["private"] == "arn:aws:lambda:eu-west-1:123456789012:network-connector:nc-22222222-2222-2222-2222-222222222222"
      && output.security_group_ids == { cicd = "sg-0123456789abcdef0", private = "sg-0123456789abcdef0" }
    )
    error_message = "Runtime and network handoff outputs must preserve every stable connector map key."
  }

  assert {
    condition = (
      length(regexall("(?s)resource\\s+\"aws_iam_role\"\\s+\"operator\".*?name\\s*=\\s*\"forge-microvm-network-operator-\\$\\{var\\.aws_region\\}\"", file("${path.module}/network_connector_operator.tf"))) == 1
      && length(regexall("(?s)resource\\s+\"aws_iam_role_policy_attachment\"\\s+\"operator\".*?policy_arn\\s*=\\s*\"arn:\\$\\{data\\.aws_partition\\.current\\.partition\\}:iam::aws:policy/AWSLambdaNetworkConnectorOperatorPolicy\"", file("${path.module}/network_connector_operator.tf"))) == 1
      && length(regexall("(?s)identity applying this stack must have iam:PassRole.*?iam:PassedToService restricted to lambda.amazonaws.com", file("${path.module}/network_connector.tf"))) == 1
      && length(regexall("vpc_id\\s*=\\s*each\\.value\\.vpc_id", file("${path.module}/network_connector_security_group.tf"))) == 1
      && length(regexall("data\\.aws_subnet\\.selected\\[\"\\$\\{each\\.key\\}/\\$\\{subnet_id\\}\"\\]\\.vpc_id\\s*==\\s*each\\.value\\.vpc_id", file("${path.module}/network_connector.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"ReadConfiguredNetworkConnectors\".*?resources\\s*=\\s*values\\(local\\.connector_arns\\)", file("${path.module}/policies.tf"))) == 1
      && length(regexall("(?s)sid\\s*=\\s*\"PassAndDiscoverNetworkConnectors\".*?resources\\s*=\\s*\\[\"\\*\"\\]", file("${path.module}/policies.tf"))) == 1
    )
    error_message = "Connector IAM must keep one AWS-managed operator role, an explicit deployment pass-role contract, scoped connector reads, and isolated pass/list permissions."
  }
}

run "rejects_subnet_from_another_vpc" {
  command = plan

  variables {
    network_connectors = {
      cicd = {
        name       = "srea_gh_runner_egress"
        vpc_id     = "vpc-0bbbbbbbbbbbbbbbb"
        subnet_ids = ["subnet-0123456789abcdef0"]
      }
      private = {
        name             = "srea-gh-runner-private"
        vpc_id           = "vpc-0123456789abcdef0"
        subnet_ids       = ["subnet-0aaaaaaaaaaaaaaaa"]
        network_protocol = "DualStack"
      }
    }
  }

  expect_failures = [aws_cloudformation_stack.connector]
}

run "rejects_unknown_network_protocol" {
  command = plan

  variables {
    network_connectors = {
      cicd = {
        name             = "srea-gh-runner-egress"
        vpc_id           = "vpc-0123456789abcdef0"
        subnet_ids       = ["subnet-0123456789abcdef0"]
        network_protocol = "IPv6"
      }
    }
  }

  expect_failures = [var.network_connectors]
}

run "rejects_empty_subnet_set" {
  command = plan

  variables {
    network_connectors = {
      cicd = {
        name       = "srea-gh-runner-egress"
        vpc_id     = "vpc-0123456789abcdef0"
        subnet_ids = []
      }
    }
  }

  expect_failures = [var.network_connectors]
}

run "rejects_empty_connector_map" {
  command = plan

  variables {
    network_connectors = {}
  }

  expect_failures = [var.network_connectors]
}

run "rejects_duplicate_connector_names" {
  command = plan

  variables {
    network_connectors = {
      first = {
        name       = "duplicate"
        vpc_id     = "vpc-0123456789abcdef0"
        subnet_ids = ["subnet-0123456789abcdef0"]
      }
      second = {
        name       = "duplicate"
        vpc_id     = "vpc-0123456789abcdef0"
        subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
      }
    }
  }

  expect_failures = [var.network_connectors]
}
