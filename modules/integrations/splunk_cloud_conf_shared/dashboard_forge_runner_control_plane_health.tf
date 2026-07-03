locals {
  forge_runner_control_plane_health_definition = templatefile(
    "${path.module}/template_files/forge_runner_control_plane_health.json.tftpl",
    {
      splunk_index = var.splunk_conf.index,
      tenants      = sort(var.splunk_conf.tenant_names)
    }
  )

  forge_runner_control_plane_health_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Forge Runner Control Plane Health</label>
    <description></description>
    <definition>
        <![CDATA[${local.forge_runner_control_plane_health_definition}]]>
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

resource "splunk_data_ui_views" "forge_runner_control_plane_health" {
  name     = "forge_runner_control_plane_health"
  eai_data = local.forge_runner_control_plane_health_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
