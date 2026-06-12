locals {
  forge_webhook_job_log_pipeline_definition = templatefile(
    "${path.module}/template_files/forge_webhook_job_log_pipeline.json.tftpl",
    {
      splunk_index = var.splunk_conf.index,
      tenants      = sort(var.splunk_conf.tenant_names)
    }
  )

  forge_webhook_job_log_pipeline_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Forge Webhook Job Log Pipeline</label>
    <description></description>
    <definition>
        <![CDATA[${local.forge_webhook_job_log_pipeline_definition}]]>
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

resource "splunk_data_ui_views" "forge_webhook_job_log_pipeline" {
  name     = "forge_webhook_job_log_pipeline"
  eai_data = local.forge_webhook_job_log_pipeline_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
