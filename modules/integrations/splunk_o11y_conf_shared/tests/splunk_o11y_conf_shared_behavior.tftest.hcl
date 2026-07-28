mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-o11y"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-secret"
    }
  }
}

mock_provider "signalfx" {
  mock_resource "signalfx_dashboard_group" {
    defaults = {
      id = "dashboard-group-123"
    }
  }

  mock_resource "signalfx_dashboard" {}
  mock_resource "signalfx_detector" {}
  mock_resource "signalfx_list_chart" {}
  mock_resource "signalfx_single_value_chart" {}
  mock_resource "signalfx_time_chart" {}
}

variables {
  aws_profile            = "test"
  aws_region             = "us-east-1"
  default_tags           = { Product = "Forge" }
  splunk_api_url         = "https://api.us1.signalfx.com"
  splunk_organization_id = "org-123"
  team                   = "forge-team"
  detector_notifications = null
  detector_name_prefix   = "Forge Prod"
  dashboard_group_name   = "Forge Dashboards"
  dashboard_variables = {
    runner_k8s = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    runner_ec2 = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    billing = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    sqs = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    s3 = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    ebs = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    lambda = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    lambda_control_plane = {
      dynamic_variables = [
        {
          property               = "aws_account_id"
          alias                  = "AWS account"
          description            = "Forge AWS accounts."
          values                 = []
          value_required         = false
          values_suggested       = ["111111111111"]
          restricted_suggestions = true
        },
        {
          property               = "aws_region"
          alias                  = "AWS region"
          description            = "Forge AWS regions."
          values                 = []
          value_required         = false
          values_suggested       = ["us-east-1"]
          restricted_suggestions = true
        },
        {
          property               = "aws_tag_ProductFamilyName"
          alias                  = "Product family"
          description            = "Forge AWS product family."
          values                 = []
          value_required         = false
          values_suggested       = ["Forge MT"]
          restricted_suggestions = true
        },
      ]
    }
    kinesis_control_plane = {
      dynamic_variables = [
        {
          property               = "aws_account_id"
          alias                  = "AWS account"
          description            = "Forge AWS accounts."
          values                 = []
          value_required         = false
          values_suggested       = ["111111111111"]
          restricted_suggestions = true
        },
        {
          property               = "aws_region"
          alias                  = "AWS region"
          description            = "Forge AWS regions."
          values                 = []
          value_required         = false
          values_suggested       = ["us-east-1"]
          restricted_suggestions = true
        },
        {
          property               = "aws_tag_ProductFamilyName"
          alias                  = "Product family"
          description            = "Forge AWS product family."
          values                 = []
          value_required         = false
          values_suggested       = ["Forge MT"]
          restricted_suggestions = true
        },
      ]
    }
    runner_logs_ingestion = {
      dynamic_variables = [
        {
          property               = "aws_account_id"
          alias                  = "AWS account"
          description            = "Forge AWS accounts."
          values                 = []
          value_required         = false
          values_suggested       = ["111111111111"]
          restricted_suggestions = true
        },
        {
          property               = "aws_region"
          alias                  = "AWS region"
          description            = "Forge AWS regions."
          values                 = []
          value_required         = false
          values_suggested       = ["us-east-1"]
          restricted_suggestions = true
        },
        {
          property               = "aws_tag_ProductFamilyName"
          alias                  = "Product family"
          description            = "Forge AWS product family."
          values                 = []
          value_required         = false
          values_suggested       = ["Forge MT"]
          restricted_suggestions = true
        },
      ]
    }
    sqs_control_plane = {
      dynamic_variables = [
        {
          property               = "aws_account_id"
          alias                  = "AWS account"
          description            = "Forge AWS accounts."
          values                 = []
          value_required         = false
          values_suggested       = ["111111111111"]
          restricted_suggestions = true
        },
        {
          property               = "aws_region"
          alias                  = "AWS region"
          description            = "Forge AWS regions."
          values                 = []
          value_required         = false
          values_suggested       = ["us-east-1"]
          restricted_suggestions = true
        },
        {
          property               = "aws_tag_ProductFamilyName"
          alias                  = "Product family"
          description            = "Forge AWS product family."
          values                 = []
          value_required         = false
          values_suggested       = ["Forge MT"]
          restricted_suggestions = true
        },
      ]
    }
    s3_control_plane = {
      dynamic_variables = []
    }
    aws_service_limits = {
      dynamic_variables = []
    }
    dynamodb = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    dependency_probes = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
    aws_regional_health = {
      dynamic_variables = [
        {
          property               = "aws_account_id"
          alias                  = "AWS account"
          description            = "Forge AWS accounts."
          values                 = []
          value_required         = false
          values_suggested       = ["111111111111"]
          restricted_suggestions = true
        },
        {
          property               = "aws_region"
          alias                  = "AWS region"
          description            = "Forge AWS regions."
          values                 = []
          value_required         = false
          values_suggested       = ["us-east-1"]
          restricted_suggestions = true
        },
        {
          property               = "aws_tag_ProductFamilyName"
          alias                  = "Product family"
          description            = "Forge AWS product family."
          values                 = []
          value_required         = false
          values_suggested       = ["Forge MT"]
          restricted_suggestions = true
        },
      ]
    }
    forge_impact = {
      tenant_names      = ["tenant-a"]
      dynamic_variables = []
    }
  }
}

run "splunk_o11y_shared_group_contract" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard_group.forgecicd.name == "Forge Dashboards"
      && signalfx_dashboard_group.forgecicd.description == ""
      && contains(signalfx_dashboard_group.forgecicd.teams, "forge-team")
    )
    error_message = "Splunk o11y shared module must create the configured dashboard group for the Forge team."
  }
}
