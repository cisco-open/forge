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
  stack_name_prefix       = "SplunkDMDataIngest"
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
    error_message = "Splunk Data Manager data input outputs must derive the configured stack name from the integration UUID and preserve inherited tags."
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
      strcontains(file("${path.module}/main.tf"), "scripts/splunk_integration.py")
      && strcontains(file("${path.module}/main.tf"), "environment = {")
      && strcontains(file("${path.module}/main.tf"), "query = {")
      && strcontains(file("${path.module}/main.tf"), "SPLUNK_CLOUD_INPUT_JSON")
      && fileset("${path.module}/scripts", "*.py") == toset(["splunk_integration.py"])
      && startswith(file("${path.module}/scripts/splunk_integration.py"), "#!/usr/bin/env python3")
      && strcontains(file("${path.module}/scripts/splunk_integration.py"), "class SplunkWebClient:")
      && strcontains(file("${path.module}/scripts/splunk_integration.py"), "def create_integration(")
      && strcontains(file("${path.module}/scripts/splunk_integration.py"), "def get_integration(")
      && strcontains(file("${path.module}/scripts/splunk_integration.py"), "def delete_integration(")
      && strcontains(file("${path.module}/scripts/splunk_integration.py"), "raise SystemExit(main())")
      && strcontains(file("${path.module}/scripts/splunk_integration.py"), "_template.json")
      && !strcontains(file("${path.module}/scripts/splunk_integration.py"), "_input.json")
      && !strcontains(file("${path.module}/scripts/splunk_integration.py"), "_request.json")
      && !strcontains(file("${path.module}/scripts/splunk_integration.py"), "_put_response.json")
      && !strcontains(file("${path.module}/scripts/splunk_integration.py"), "_hectoken.json")
      && !strcontains(file("${path.module}/scripts/splunk_integration.py"), "_logs.txt")
    )
    error_message = "Splunk Data Manager must use one self-contained Python lifecycle command, keep runtime state in memory, and write only the template artifact."
  }

  assert {
    condition = (
      length(regexall("SPLUNK_CLOUD_USERNAME\\s*=\\s*nonsensitive\\(", file("${path.module}/main.tf"))) == 2
      && length(regexall("SPLUNK_CLOUD_PASSWORD\\s*=\\s*nonsensitive\\(", file("${path.module}/main.tf"))) == 2
      && length(regexall("nonsensitive\\(", file("${path.module}/main.tf"))) == 4
    )
    error_message = "Splunk Data Manager must declassify only the four local-exec credential environment values so sanitized Python diagnostics remain visible."
  }
}
