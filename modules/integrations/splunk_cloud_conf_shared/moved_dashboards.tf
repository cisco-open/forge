moved {
  from = splunk_data_ui_views.forge_arc_dind_health
  to   = splunk_data_ui_views.forge_arc_dind_runner_lifecycle
}

moved {
  from = splunk_data_ui_views.forge_arc_k8s_runner_health
  to   = splunk_data_ui_views.forge_arc_k8s_runner_lifecycle
}

moved {
  from = splunk_data_ui_views.ci_jobs
  to   = splunk_data_ui_views.forge_ci_job_details
}

moved {
  from = splunk_data_ui_views.github_webhook_workflow_jobs
  to   = splunk_data_ui_views.forge_github_webhook_workflow_job_events
}

moved {
  from = splunk_data_ui_views.forge_k8s_storage_network
  to   = splunk_data_ui_views.forge_kubernetes_storage_and_network
}

moved {
  from = splunk_data_ui_views.tenant
  to   = splunk_data_ui_views.forge_tenant_logs
}

moved {
  from = splunk_data_ui_views.forge_webhook_joblog_pipeline
  to   = splunk_data_ui_views.forge_webhook_job_log_pipeline
}
