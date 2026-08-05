mock_provider "aws" {
  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk_cloud_api_token"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-api-token"
    }
  }
}

mock_provider "splunk" {
  mock_resource "splunk_data_ui_views" {}
  mock_resource "splunk_configs_conf" {}
}

variables {
  aws_profile  = "test"
  aws_region   = "us-east-1"
  default_tags = { Product = "Forge" }
  splunk_conf = {
    splunk_cloud = "https://splunk.example.com"
    index        = "forge-prod-index"
    tenant_names = ["tenant-b", "tenant-a"]
    acl = {
      app     = "search"
      owner   = "nobody"
      sharing = "app"
      read    = ["*"]
      write   = ["admin"]
    }
  }
  stuck_workflow_job_dispatcher_name_prefix = "forge-dispatcher"
}

run "splunk_cloud_shared_dashboard_and_props_contract" {
  command = plan

  assert {
    condition = (
      splunk_data_ui_views.forge_ci_job_details.name == "forge_ci_job_details"
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "Forge CI Job Details")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "forge-prod-index")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "tenant-a")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "tenant-b")
    )
    error_message = "Splunk shared config must render the CI job details dashboard from the configured index and sorted tenant list."
  }

  assert {
    condition = (
      splunk_data_ui_views.forge_ci_job_details.acl[0].app == "search"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].owner == "nobody"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].sharing == "app"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].read[0] == "*"
      && splunk_data_ui_views.forge_ci_job_details.acl[0].write[0] == "admin"
    )
    error_message = "Splunk dashboards must propagate the configured ACL values."
  }

  assert {
    condition = (
      splunk_configs_conf.forgecicd_runner_logs_s3.name == "props/forgecicd:runner-logs:s3"
      && splunk_configs_conf.forgecicd_runner_logs_s3.variables["REPORT-forgecicd_runner_logs_tenant_fields_logs"] == "forgecicd_runner_logs_tenant_fields_logs"
      && splunk_configs_conf.forgecicd_runner_logs_s3.variables["TRUNCATE"] == "1000000"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_logs.variables["REGEX"] == "^s3:\\/\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-forge-gh-logs-(?<account_id>\\d+)\\/(?<github_org>[a-zA-Z0-9._-]+)\\/(?<github_repo>[a-zA-Z0-9._-]+)\\/(?<workflow_run>\\d+)\\/(?<attempt>\\d+)\\/(?<job_id>\\d+)\\.log$"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_logs.variables["FORMAT"] == "forgecicd_tenant::$1 forgecicd_region_alias::$2 forgecicd_vpc_alias::$3 github_org::$5 github_repo::$6 workflow_run::$7 attempt::$8 job_id::$9 forgecicd_log_type::runner-job-logs"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_logs.variables["SOURCE_KEY"] == "source"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_logs.variables["CLEAN_KEYS"] == "0"
      && try(
        regex(
          splunk_configs_conf.forgecicd_runner_logs_tenant_fields_logs.variables["REGEX"],
          "s3://srea-euw1-sl-forge-gh-logs-152772858171/cisco-sbg-emu/cloudsec_srea_forge-installation-test/31038335761/1/92416147467.log",
        ),
        {},
        ) == {
        account_id             = "152772858171"
        attempt                = "1"
        forgecicd_region_alias = "euw1"
        forgecicd_tenant       = "srea"
        forgecicd_vpc_alias    = "sl"
        github_org             = "cisco-sbg-emu"
        github_repo            = "cloudsec_srea_forge-installation-test"
        job_id                 = "92416147467"
        workflow_run           = "31038335761"
      }
    )
    error_message = "Splunk shared props must extract tenant and GitHub run identifiers from S3 runner-log source URIs."
  }

  assert {
    condition = (
      splunk_configs_conf.forgecicd_runner_logs_s3.variables["REPORT-forgecicd_runner_logs_tenant_fields_event"] == "forgecicd_runner_logs_tenant_fields_event"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_event.variables["REGEX"] == "^s3:\\/\\/(?<forgecicd_tenant>[a-z0-9]+)-(?<forgecicd_region_alias>[a-z0-9]+)-(?<forgecicd_vpc_alias>[a-z0-9]+)-forge-gh-logs-(?<account_id>\\d+)\\/(?<github_org>[a-zA-Z0-9._-]+)\\/(?<github_repo>[a-zA-Z0-9._-]+)\\/(?<workflow_run>\\d+)\\/(?<attempt>\\d+)\\/(?<job_id>\\d+)\\.json$"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_event.variables["FORMAT"] == "forgecicd_tenant::$1 forgecicd_region_alias::$2 forgecicd_vpc_alias::$3 github_org::$5 github_repo::$6 workflow_run::$7 attempt::$8 job_id::$9 forgecicd_log_type::runner-job-event"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_event.variables["SOURCE_KEY"] == "source"
      && splunk_configs_conf.forgecicd_runner_logs_tenant_fields_event.variables["CLEAN_KEYS"] == "0"
      && try(
        regex(
          splunk_configs_conf.forgecicd_runner_logs_tenant_fields_event.variables["REGEX"],
          "s3://srea-euw1-sl-forge-gh-logs-152772858171/cisco-sbg-emu/cloudsec_srea_forge-installation-test/31038335761/1/92416147467.json",
        ),
        {},
        ) == {
        account_id             = "152772858171"
        attempt                = "1"
        forgecicd_region_alias = "euw1"
        forgecicd_tenant       = "srea"
        forgecicd_vpc_alias    = "sl"
        github_org             = "cisco-sbg-emu"
        github_repo            = "cloudsec_srea_forge-installation-test"
        job_id                 = "92416147467"
        workflow_run           = "31038335761"
      }
    )
    error_message = "Splunk shared props must extract tenant and GitHub run identifiers from S3 runner-event source URIs."
  }

  assert {
    condition = (
      splunk_configs_conf.forgecicd_cloudwatchlogs.variables["REPORT-forgecicd_shared_lambda_fields"] == "forgecicd_shared_lambda_fields"
      && splunk_configs_conf.forgecicd_shared_lambda_fields.name == "transforms/forgecicd_shared_lambda_fields"
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "splunk-dependency-monitor")
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "forge-aws-billing-per-service")
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "forge-aws-billing-per-resource-process")
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "forge-aws-billing-per-resource")
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "webex-webhook-relay-destination-receiver")
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "SplunkDMMetadataEC2InstPatternTags")
      && strcontains(splunk_configs_conf.forgecicd_shared_lambda_fields.variables["REGEX"], "SplunkDMMetadataEC2Inst")
      && splunk_configs_conf.forgecicd_shared_lambda_fields.variables["FORMAT"] == "aws_region::$1 forgecicd_log_type::$2"
    )
    error_message = "Splunk shared Lambda extraction must cover every Forge-managed shared Lambda and normalize its region and log type fields."
  }
}
