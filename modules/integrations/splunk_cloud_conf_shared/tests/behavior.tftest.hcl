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
  mock_resource "splunk_transforms_regex" {}
}

run "splunk_cloud_shared_dashboard_and_props_contract" {
  command = plan

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

run "orders_arc_and_kubernetes_dashboards_for_operator_triage" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
      acl = {
        app = "search", owner = "nobody", sharing = "app", read = ["*"], write = ["admin"]
      }
    }
  }

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_arc_dind_runner_lifecycle.eai_data,
        splunk_data_ui_views.forge_arc_k8s_runner_lifecycle.eai_data,
        splunk_data_ui_views.forge_kubernetes_storage_and_network.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "ARC and Kubernetes dashboards must keep guidance in compact panel descriptions."
  }

  assert {
    condition = (
      can(regex("\"item\": \"init_failures_table\"[\\s\\S]*\"item\": \"dind_trend_chart\"[\\s\\S]*\"item\": \"runner_version_table\"", splunk_data_ui_views.forge_arc_dind_runner_lifecycle.eai_data))
      && can(regex("\"item\": \"k8s_pod_events_table\"[\\s\\S]*\"item\": \"k8s_hook_trend_chart\"[\\s\\S]*\"item\": \"k8s_runner_version_table\"", splunk_data_ui_views.forge_arc_k8s_runner_lifecycle.eai_data))
    )
    error_message = "ARC lifecycle dashboards must place actionable pod, PVC, hook, and init failures before trends and inventory."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_kubernetes_storage_and_network.eai_data, "This is diagnostic proximity, not proof of causality")
      && strcontains(splunk_data_ui_views.forge_kubernetes_storage_and_network.eai_data, "validate the exact workflow job and resource identifiers")
    )
    error_message = "Kubernetes job-overlap panels must explicitly avoid claiming causality from time-window proximity."
  }
}

run "orders_control_plane_dashboards_for_operator_triage" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
      acl = {
        app = "search", owner = "nobody", sharing = "app", read = ["*"], write = ["admin"]
      }
    }
  }

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_runner_capacity.eai_data,
        splunk_data_ui_views.forge_runner_control_plane_health.eai_data,
        splunk_data_ui_views.forge_trust_failures.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "Capacity, control-plane, and trust dashboards must keep guidance in compact panel descriptions."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_capacity.eai_data, "One elevated percentile is not enough to infer failure")
      && strcontains(splunk_data_ui_views.forge_runner_capacity.eai_data, "sourcetype=\\\"forgecicd:runner-logs:s3\\\" source=\\\"*.json\\\"")
      && strcontains(splunk_data_ui_views.forge_runner_capacity.eai_data, "spath input=_raw path=workflow_job.created_at")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Global-lock cleanup is diagnostic and is not causal evidence for a stuck job")
      && strcontains(splunk_data_ui_views.forge_trust_failures.eai_data, "TagSession")
    )
    error_message = "Capacity must use native S3 JSON metadata, while control-plane guidance prevents single-chart failure inference, false global-lock causality, and incomplete STS trust triage."
  }

  assert {
    condition = (
      can(regex("\"item\": \"queue_pressure_table\"[\\s\\S]*\"item\": \"queue_trend_chart\"", splunk_data_ui_views.forge_runner_capacity.eai_data))
      && can(regex("\"item\": \"assume_role_failures_table\"[\\s\\S]*\"item\": \"trust_failure_trend_chart\"[\\s\\S]*\"item\": \"latest_validation_table\"", splunk_data_ui_views.forge_trust_failures.eai_data))
    )
    error_message = "Capacity and trust dashboards must place actionable failures before trend and investigation detail."
  }

  assert {
    condition = (
      can(jsondecode(local.forge_runner_control_plane_health_definition))
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "GitHub rate limit: Request quota exhausted")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "isJobQueued check failed, assuming job is still queued (fail-open)")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "body is not valid JSON")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "SQS messages will be retried.")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Checking current ec2 pool size")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Runner creation summary.")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "requestedMessageCount")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "Failed to mark EC2 runner")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "EC2 runner '(?<provider_instance_id>")
    )
    error_message = "Runner control-plane searches must use only the v7.10.1 API, SQS, pool, scale-up, and scale-down log contract."
  }

  assert {
    condition = (
      splunk_configs_conf.forgecicd_pool_target_size.variables.REGEX == "Checking current ec2 pool size against pool of size: ([0-9]+)"
      && splunk_configs_conf.forgecicd_scale_down_aws_runner_instance_id.variables.REGEX == "EC2 runner '(i-[0-9a-f]+)'"
    )
    error_message = "Control-plane field extractions must use only the v7.10.1 provider-aware messages."
  }
}

run "orders_dispatcher_dashboards_for_operator_triage" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      acl = {
        app     = "search_app_srea"
        owner   = "nobody"
        sharing = "app"
        read    = ["*"]
        write   = ["admin"]
      }
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
    }
    stuck_workflow_job_dispatcher_name_prefix = "forge-dispatcher"
  }

  assert {
    condition = (
      can(regex(
        "\"item\": \"dispatcher_rejection_summary_table\"[\\s\\S]*\"item\": \"dispatcher_rejection_trend_chart\"[\\s\\S]*\"item\": \"dispatcher_rejection_examples_table\"",
        splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data,
      ))
      && !strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "\"operator_guide\"")
      && strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "age_minutes")
    )
    error_message = "Dispatcher rejections must lead with actionable scope, expose age, and leave raw samples last without a guide row."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "sourcetype IN (\\\"aws:cloudwatchlogs\\\",\\\"aws:cloudwatchlogs:forgecicd\\\") source=\\\"*:/aws/lambda/*dispatch-to-runner:*\\\"")
      && strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "| search forgecicd_log_type=\\\"dispatch-to-runner\\\"")
      && !strcontains(splunk_data_ui_views.forge_runner_dispatcher_rejections.eai_data, "index=\\\"srea-forge-prod-index\\\" forgecicd_log_type=")
    )
    error_message = "Dispatcher SPL must constrain indexed sourcetype and Lambda source before applying the search-time dispatcher field."
  }

  assert {
    condition = (
      !strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "\"operator_guide\"")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_debug.eai_data, "Use this drilldown only after the health dashboard")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_debug.eai_data, "Global locks are not assumed causal")
      && !strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_debug.eai_data, "\"operator_guide\"")
    )
    error_message = "Stuck-job health and debug dashboards must keep compact workflow guidance and the non-causal global-lock boundary."
  }
}

run "orders_ec2_failure_dashboards_for_operator_triage" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
      acl = {
        app = "search", owner = "nobody", sharing = "app", read = ["*"], write = ["admin"]
      }
    }
  }

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data,
        splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data,
        splunk_data_ui_views.forge_ec2_runner_lifecycle.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
    ])
    error_message = "EC2 dashboards must keep operational guidance in compact panel descriptions."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data, "source=\\\"*:/aws/lambda/*scale-up:*\\\"")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "source=\\\"*:/aws/lambda/*scale-up:*\\\"")
      && strcontains(splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data, "| search forgecicd_log_type=\\\"scale-up\\\"")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "| search forgecicd_log_type=\\\"scale-up\\\"")
    )
    error_message = "Scale-up failure searches must apply indexed sourcetype and Lambda-source constraints before search-time fields."
  }

  assert {
    condition = (
      can(regex("\"item\": \"tenant_error_summary_table\"[\\s\\S]*\"item\": \"fleet_error_trend_chart\"[\\s\\S]*\"item\": \"request_drilldown_table\"", splunk_data_ui_views.forge_ec2_fleet_scale_up_failures.eai_data))
      && can(regex("\"item\": \"run_instances_summary_table\"[\\s\\S]*\"item\": \"run_instances_error_trend_chart\"[\\s\\S]*\"item\": \"run_instances_drilldown_table\"", splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data))
    )
    error_message = "EC2 failure dashboards must place scope and actionable failures before trends and request drilldowns."
  }

  assert {
    condition = (
      can(jsondecode(local.forge_ec2_run_instances_scale_up_failures_definition))
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "RunInstances request failed for dedicated host.")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "RunInstances did not create every requested instance.")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "SQS messages will be retried.")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "messageIds{}")
      && strcontains(splunk_data_ui_views.forge_ec2_run_instances_scale_up_failures.eai_data, "nonRetryableErrorCount")
    )
    error_message = "RunInstances searches must use only the v7.10.1 failure and retry log contract."
  }
}

run "orders_ingestion_dashboards_for_operator_triage" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
      acl = {
        app = "search", owner = "nobody", sharing = "app", read = ["*"], write = ["admin"]
      }
    }
  }

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_ingestion_quality.eai_data,
        splunk_data_ui_views.forge_lambda_operations.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\": \"Answers")
      && strcontains(body, "$global_time.earliest$")
      && strcontains(body, "$global_time.latest$")
    ])
    error_message = "Ingestion dashboards must keep guidance in panel descriptions and retain the global-time token."
  }

  assert {
    condition = (
      can(regex("\"item\": \"missing_fields_table\"[\\s\\S]*\"item\": \"volume_anomaly_chart\"[\\s\\S]*\"item\": \"source_inventory_table\"", splunk_data_ui_views.forge_ingestion_quality.eai_data))
      && can(regex("\"item\": \"lambda_errors_table\"[\\s\\S]*\"item\": \"lambda_error_trend_chart\"[\\s\\S]*\"item\": \"lambda_samples_table\"", splunk_data_ui_views.forge_lambda_operations.eai_data))
      && strcontains(splunk_data_ui_views.forge_ingestion_quality.eai_data, "forgecicd:runner-logs:s3")
      && !strcontains(splunk_data_ui_views.forge_ingestion_quality.eai_data, "splunk-s3-runner-logs")
      && !strcontains(splunk_data_ui_views.forge_lambda_operations.eai_data, "splunk-s3-runner-logs")
    )
    error_message = "Ingestion and Lambda dashboards must retain useful diagnostics without references to the retired runner-log streaming pipeline."
  }
}

run "makes_investigation_dashboards_explicitly_diagnostic" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
      acl = {
        app = "search", owner = "nobody", sharing = "app", read = ["*"], write = ["admin"]
      }
    }
  }

  assert {
    condition = alltrue([
      for body in [
        splunk_data_ui_views.forge_ci_job_details.eai_data,
        splunk_data_ui_views.forge_tenant_logs.eai_data,
        splunk_data_ui_views.forge_troubleshooting.eai_data,
      ] :
      !strcontains(body, "\"operator_guide\"")
      && !strcontains(body, "\"type\": \"splunk.markdown\"")
      && strcontains(body, "\"description\":")
    ])
    error_message = "Investigation dashboards must keep guidance in compact panel descriptions rather than a dedicated guide row."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "Which tenant log events match the investigation?")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "an empty result can mean no matching retained events")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "Raw logs provide evidence but do not assign")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "sourcetype=\\\"forgecicd:runner-logs:s3\\\"")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "eventstats latest(runner_job_json)")
      && strcontains(splunk_data_ui_views.forge_tenant_logs.eai_data, "spath input=runner_job_json path=workflow_job.runner_name")
    )
    error_message = "Tenant logs must correlate native S3 log objects with sibling JSON metadata without overstating empty results or ownership."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "\"description\": \"Answers")
      && strcontains(splunk_data_ui_views.forge_troubleshooting.eai_data, "\"description\": \"Answers")
      && can(regex("\"item\": \"queued_windows_table\"[\\s\\S]*\"item\": \"ci_job_details_table\"", splunk_data_ui_views.forge_ci_job_details.eai_data))
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "sourcetype=\\\"forgecicd:runner-logs:s3\\\" source=\\\"*.json\\\"")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "spath input=_raw path=workflow_job.runner_name")
      && strcontains(splunk_data_ui_views.forge_ci_job_details.eai_data, "eval forgecicd_type=case")
      && strcontains(splunk_data_ui_views.forge_troubleshooting.eai_data, "sourcetype=\\\"forgecicd:runner-logs:s3\\\" source=\\\"*.json\\\"")
    )
    error_message = "CI and troubleshooting panels must query native S3 JSON explicitly, extract metadata with spath, and leave high-cardinality job detail after queue diagnostics."
  }
}

run "separates_stuck_job_path_from_global_lock_cleanup" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      acl = {
        app     = "search_app_srea"
        owner   = "nobody"
        sharing = "app"
        read    = ["*"]
        write   = ["admin"]
      }
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
    }
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "\"stuck_job_control_plane_path_search\"")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "webhook_queued")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "initial_dispatch")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "redelivery_completed")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "runner_in_progress")
      && strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "Forge Runner Capacity plus the EC2 or ARC lifecycle dashboard")
      && !strcontains(splunk_data_ui_views.stuck_workflow_job_dispatcher_health.eai_data, "Redelivery and Global Lock Correlation")
    )
    error_message = "The stuck-job health dashboard must follow the webhook, dispatch, redelivery, and runner-start path without implying global-lock causality."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "\"global_lock_cleanup_search\"")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "source=\\\"*:/aws/lambda/*clean-global-lock*:*\\\"")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "github_lookup_failed")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "malformed_lock_record")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "completed_lock_not_deleted")
      && strcontains(splunk_data_ui_views.forge_runner_control_plane_health.eai_data, "No stale-lock conclusion: lock age is not emitted")
    )
    error_message = "Global-lock cleanup must be diagnostic control-plane health and must not infer staleness without lock-age telemetry."
  }
}

run "organizes_webhook_health_for_operator_triage" {
  command = plan

  variables {
    aws_profile  = "test"
    aws_region   = "us-east-1"
    default_tags = { Product = "Forge" }
    splunk_conf = {
      splunk_cloud = "https://example.splunkcloud.com"
      acl = {
        app     = "search_app_srea"
        owner   = "nobody"
        sharing = "app"
        read    = ["*"]
        write   = ["admin"]
      }
      index        = "srea-forge-prod-index"
      tenant_names = ["tenant-a"]
    }
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_jobs_base_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_jobs_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"queued_jobs_summary_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"webhook_relay_health_search\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "aws:cloudwatchlogs:forgecicd")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "source=\\\"*:/aws/lambda/*-webhook:*\\\"")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "age_seconds")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "queued_webhook")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "runner_in_progress")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "runner_completed")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "age_seconds>900 AND age_seconds<=86400")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "spath path=github.workflowJobId output=workflow_job_id")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "ds.chain")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Successfully dispatched job for")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Received event contains runner labels")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "source=\\\"*:/aws/lambda/*-dispatch-to-runner:*\\\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"delivery_chain_gaps_search\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "workflow_ids_by_delivery")
    )
    error_message = "The webhook dashboard must derive queued-job aging from structured webhook lifecycle fields without legacy dispatcher parsing or an unsupported relay-to-tenant join."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "*validate-signature*")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Received GitHub webhook")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Signature mismatch")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Event forwarded to EventBridge")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "eventbridge_failed")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "lambda_error")
    )
    error_message = "Relay receipt, rejection, forwarding, and Lambda failures must remain a separate shared-platform health signal."
  }

  assert {
    condition = (
      strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Workflow jobs still queued")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Healthy: 0")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Healthy: no rows")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Which workflow jobs remain queued?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Is the shared webhook relay forwarding events?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "How is workflow-job activity trending?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "Which workflow-job webhook events were received?")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "timechart span=15m dc(workflow_job_id) by status")
      && strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "operator_action")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"operator_guide\"")
      && !strcontains(splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data, "\"type\": \"splunk.markdown\"")
    )
    error_message = "The webhook dashboard must explain healthy results, ask operator-oriented questions, add workflow trends, and avoid a dedicated guide row."
  }

  assert {
    condition = (
      length(regexall("(?s)\"item\":\\s*\"queued_jobs_single\".*?\"y\":\\s*0", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"queued_jobs_table\".*?\"y\":\\s*220", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"webhook_relay_health_chart\".*?\"y\":\\s*580", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"workflow_activity_trend_chart\".*?\"y\":\\s*1200", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
      && length(regexall("(?s)\"item\":\\s*\"github_webhook_workflow_jobs_table\".*?\"y\":\\s*2260", splunk_data_ui_views.forge_github_webhook_workflow_job_events.eai_data)) == 1
    )
    error_message = "The dashboard must order queued-job summary cards, the actionable queue table, relay health, trends, and raw events from top to bottom."
  }
}
