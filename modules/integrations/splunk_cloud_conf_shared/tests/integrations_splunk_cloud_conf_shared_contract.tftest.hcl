run "integrations_splunk_cloud_conf_shared_contract" {
  command = plan

  module {
    source = "../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"splunk_data_ui_views\" \"forge_arc_dind_runner_lifecycle\"",
      "resource \"splunk_data_ui_views\" \"forge_arc_k8s_runner_lifecycle\"",
      "resource \"splunk_data_ui_views\" \"forge_ci_job_details\"",
      "resource \"splunk_data_ui_views\" \"forge_ec2_fleet_scale_up_failures\"",
      "resource \"splunk_data_ui_views\" \"forge_ec2_run_instances_scale_up_failures\"",
      "resource \"splunk_data_ui_views\" \"forge_ec2_runner_lifecycle\"",
      "resource \"splunk_data_ui_views\" \"forge_github_webhook_workflow_job_events\"",
      "resource \"splunk_data_ui_views\" \"forge_ingestion_quality\"",
      "resource \"splunk_data_ui_views\" \"forge_kubernetes_storage_and_network\"",
      "resource \"splunk_data_ui_views\" \"forge_lambda_operations\"",
      "resource \"splunk_data_ui_views\" \"forge_runner_capacity\"",
      "resource \"splunk_data_ui_views\" \"forge_runner_control_plane_health\"",
      "resource \"splunk_data_ui_views\" \"forge_runner_dispatcher_rejections\"",
      "resource \"splunk_data_ui_views\" \"stuck_workflow_job_dispatcher_health\"",
      "resource \"splunk_data_ui_views\" \"stuck_workflow_job_dispatcher_debug\"",
      "resource \"splunk_data_ui_views\" \"forge_tenant_logs\"",
      "resource \"splunk_data_ui_views\" \"forge_troubleshooting\"",
      "resource \"splunk_data_ui_views\" \"forge_trust_failures\"",
      "resource \"splunk_data_ui_views\" \"forge_webhook_job_log_pipeline\"",
      "resource \"splunk_configs_conf\" \"forgecicd_aws_billing_cur\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_forgecicd\"",
      "resource \"splunk_configs_conf\" \"forgecicd_metadata\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_runner\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_runner_logs\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_init_docker_creds\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_init_dind_rootless\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_init_work\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_init_dind_externals\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_dind\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_listener\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_manager\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_log_worker\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_log_hook\"",
      "resource \"splunk_configs_conf\" \"forgecicd_runner_logs_json\"",
      "resource \"splunk_configs_conf\" \"forgecicd_runner_logs_logs\"",
      "resource \"splunk_configs_conf\" \"forgecicd_billing_cur_instance_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_billing_cur_volume_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_runner_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_runner_pages_github_repo_name\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_extract_log_time_message\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_global_lambda_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_lambda_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_metadata_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_metadata_instance_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_metadata_image_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_metadata_instance_type\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_runner_ci_result\"",
      "resource \"splunk_configs_conf\" \"forgecicd_cloudwatchlogs_runner_gh_runner_version\"",
      "resource \"splunk_configs_conf\" \"forgecicd_eks_control_plane_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_runner_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_listener_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_manager_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_runner_ci_result\"",
      "resource \"splunk_configs_conf\" \"forgecicd_kube_container_runner_gh_runner_version\"",
      "resource \"splunk_configs_conf\" \"forgecicd_extra_lambda_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_extra_lambda_ec2_tenant_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_trust_validation\"",
      "resource \"splunk_configs_conf\" \"forgecicd_dispatch_to_runner_rejection_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_pool_target_size\"",
      "resource \"splunk_configs_conf\" \"forgecicd_pool_top_up\"",
      "resource \"splunk_configs_conf\" \"forgecicd_pool_idle_runners\"",
      "resource \"splunk_configs_conf\" \"forgecicd_pool_top_up_cap\"",
      "resource \"splunk_configs_conf\" \"forgecicd_scale_down_runner_instance_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_scale_down_aws_runner_instance_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_scale_down_orphan_runner_instance_id\"",
      "resource \"splunk_configs_conf\" \"forgecicd_runner_logs_tenant_fields_event\"",
      "resource \"splunk_configs_conf\" \"forgecicd_runner_logs_tenant_fields_logs\"",
      "resource \"splunk_configs_conf\" \"forgecicd_runner_ec2\"",
      "resource \"splunk_configs_conf\" \"forgecicd_runner_arc\"",
      "resource \"splunk_configs_conf\" \"forgecicd_stuck_workflow_job_dispatcher_delivery_attempt\"",
      "resource \"splunk_configs_conf\" \"forgecicd_stuck_workflow_job_dispatcher_generic_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_stuck_workflow_job_dispatcher_key_fields\"",
      "resource \"splunk_configs_conf\" \"forgecicd_stuck_workflow_job_dispatcher_receiver_source\"",
      "resource \"splunk_configs_conf\" \"forgecicd_stuck_workflow_job_dispatcher_runner_group\"",
      "resource \"splunk_configs_conf\" \"forgecicd_stuck_workflow_job_dispatcher_worker_source\"",
      "data \"aws_secretsmanager_secret\" \"secrets\"",
      "data \"aws_secretsmanager_secret_version\" \"secrets\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Module contract is missing expected literals: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count > 0
    error_message = "Module contract must pin at least one module-specific literal."
  }
}
