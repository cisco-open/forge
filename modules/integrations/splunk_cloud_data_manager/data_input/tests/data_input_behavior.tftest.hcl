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
        version       = "9.3.0"
        template_hash = "template-sha"
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
      version       = "9.3.0"
    }
  }
}

run "splunk_data_input_template_contract" {
  command = plan

  assert {
    condition = (
      output.splunk_integration_name == "SplunkDMDataIngest-00000000-0000-0000-0000-000000000001"
      && output.splunk_integration_tags.Product == "Forge"
      && output.splunk_integration_tags.Env == "test"
    )
    error_message = "Splunk Data Manager data input outputs must derive stack name from the integration UUID and preserve inherited tags."
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
}
