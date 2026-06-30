locals {
  stuck_workflow_job_dispatcher_health_dashboard_name = "forge_stuck_workflow_job_dispatcher_health"
  stuck_workflow_job_dispatcher_debug_dashboard_name  = "forge_stuck_workflow_job_dispatcher_debug"

  stuck_workflow_job_dispatcher_health_definition = templatefile(
    "${path.module}/template_files/forge_stuck_workflow_job_dispatcher_health.json.tftpl",
    {
      receiver_lambda_name = var.stuck_workflow_job_dispatcher_name_prefix,
      splunk_index         = var.splunk_conf.index,
      tenants              = sort(var.splunk_conf.tenant_names),
      worker_lambda_name   = "${var.stuck_workflow_job_dispatcher_name_prefix}-worker"
    }
  )

  stuck_workflow_job_dispatcher_debug_definition = templatefile(
    "${path.module}/template_files/forge_stuck_workflow_job_dispatcher_debug.json.tftpl",
    {
      receiver_lambda_name = var.stuck_workflow_job_dispatcher_name_prefix,
      splunk_index         = var.splunk_conf.index,
      tenants              = sort(var.splunk_conf.tenant_names),
      worker_lambda_name   = "${var.stuck_workflow_job_dispatcher_name_prefix}-worker"
    }
  )

  stuck_workflow_job_dispatcher_health_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Forge Stuck Workflow Job Dispatcher Health</label>
    <description>Health, alert quality, redelivery outcomes, and hot spots for stuck workflow_job redelivery.</description>
    <definition>
        <![CDATA[${local.stuck_workflow_job_dispatcher_health_definition}]]>
    </definition>
    <meta type="hiddenElements">
        <![CDATA[
{
    "hideEdit": false,
    "hideOpenInSearch": false,
    "hideExport": false
}
        ]]>
    </meta>
</dashboard>
EOF

  stuck_workflow_job_dispatcher_debug_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Forge Stuck Workflow Job Dispatcher Debug</label>
    <description>Per-key lifecycle, runner capacity decisions, delivery attempts, and raw samples for stuck workflow_job redelivery.</description>
    <definition>
        <![CDATA[${local.stuck_workflow_job_dispatcher_debug_definition}]]>
    </definition>
    <meta type="hiddenElements">
        <![CDATA[
{
    "hideEdit": false,
    "hideOpenInSearch": false,
    "hideExport": false
}
        ]]>
    </meta>
</dashboard>
EOF
}

resource "splunk_data_ui_views" "stuck_workflow_job_dispatcher_health" {
  name     = local.stuck_workflow_job_dispatcher_health_dashboard_name
  eai_data = local.stuck_workflow_job_dispatcher_health_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}

resource "splunk_data_ui_views" "stuck_workflow_job_dispatcher_debug" {
  name     = local.stuck_workflow_job_dispatcher_debug_dashboard_name
  eai_data = local.stuck_workflow_job_dispatcher_debug_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
