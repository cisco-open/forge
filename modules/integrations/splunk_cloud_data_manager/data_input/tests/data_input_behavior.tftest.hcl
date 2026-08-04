mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-cloud"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-secret"
    }
  }
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        version       = "1"
        template_hash = "template-sha"
        stack_name    = "SplunkDMSqsS3-00000000-0000-0000-0000-000000000001"
      }
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "null" {}
mock_provider "local" {}
mock_provider "time" {}

variables {
  splunk_cloud            = "https://splunk.example.com"
  splunk_cloud_input_json = "{\"name\":\"cloudwatch\"}"
  tags_all = {
    Product = "Forge"
    Env     = "test"
  }
  cloudformation_s3_config = {
    bucket = "forge-templates"
    key    = "splunk/"
  }
}

override_data {
  target = data.external.splunk_dm_version
  values = {
    result = {
      template_hash = "template-sha"
      version       = "1"
      stack_name    = "SplunkDMSqsS3-00000000-0000-0000-0000-000000000001"
    }
  }
}

run "splunk_data_input_template_contract" {
  command = plan

  assert {
    condition = (
      output.splunk_integration_tags.Product == "Forge"
      && output.splunk_integration_tags.Env == "test"
    )
    error_message = "Splunk Data Manager data input outputs must preserve inherited tags."
  }

  assert {
    condition = (
      aws_s3_object.cloudformation_template.bucket == "forge-templates"
      && aws_s3_object.cloudformation_template.source == "/tmp/00000000-0000-0000-0000-000000000001_template.json"
    )
    error_message = "Splunk Data Manager data input must upload the downloaded CloudFormation template artifact to the configured S3 bucket."
  }

  assert {
    condition = (
      null_resource.create_integration.triggers.splunk_cloud_input_json == "{\"name\":\"cloudwatch\"}"
      && null_resource.create_integration.triggers.splunk_cloud == "https://splunk.example.com"
      && null_resource.create_integration.triggers.splunk_input_uuid == "00000000-0000-0000-0000-000000000001"
    )
    error_message = "Splunk Data Manager data input create trigger must track input JSON, cloud URL, and generated integration UUID."
  }

  assert {
    condition = (
      strcontains(file("${path.module}/scripts/create_splunk_integration.sh"), "grep -v '^s3-custom-logs$'")
      && strcontains(file("${path.module}/scripts/get_splunk_integration.sh"), "grep -v '^s3-custom-logs$'")
      && strcontains(file("${path.module}/scripts/create_splunk_integration.sh"), "splunk_wait_for_s3_input")
      && strcontains(file("${path.module}/scripts/get_splunk_integration.sh"), "splunk_wait_for_s3_input")
      && strcontains(file("${path.module}/scripts/splunk_integration_helpers.sh"), "splunk_s3_input_state")
      && strcontains(file("${path.module}/scripts/splunk_integration_helpers.sh"), "splunk_s3_input_matches_request")
      && strcontains(file("${path.module}/scripts/splunk_integration_helpers.sh"), "splunk_s3_input_matches_version")
      && strcontains(file("${path.module}/scripts/splunk_integration_helpers.sh"), "splunk_s3_input_matches_update_time")
      && strcontains(file("${path.module}/scripts/splunk_integration_helpers.sh"), "splunk_validate_cloudformation_template")
      && strcontains(file("${path.module}/main.tf"), "export SPLUNK_CLOUD_INPUT_JSON=")
      && strcontains(file("${path.module}/scripts/get_splunk_integration.sh"), "stack_name: .details.stackName")
      && strcontains(file("${path.module}/scripts/get_splunk_integration.sh"), ".details.version | tostring")
      && strcontains(file("${path.module}/scripts/delete_splunk_integration.sh"), ".dataSourcesStatus")
      && strcontains(file("${path.module}/scripts/delete_splunk_integration.sh"), "if jq -e '.details.datasetInfo | has(\"s3-custom-logs\")'")
      && strcontains(file("${path.module}/scripts/delete_splunk_integration.sh"), "DATASETS=(\"aws-cwl\" \"cwl-custom-logs\" \"cwl-vpc-flow-logs\" \"cloudtrail\" \"securityhub\" \"guardduty\" \"iam-aa\" \"iam-cr\" \"metadata\")")
    )
    error_message = "Splunk Data Manager scripts must match the requested S3 update and version, wait for every queue, validate the template, skip S3 HEC calls, preserve push-input HEC cleanup, and normalize response-only fields."
  }
}
