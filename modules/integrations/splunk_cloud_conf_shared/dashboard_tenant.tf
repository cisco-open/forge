locals {
  tenant_definition = templatefile(
    "${path.module}/template_files/tenant.json.tftpl",
    {
      splunk_index = var.splunk_conf.index,
      tenants      = var.splunk_conf.tenant_names
    }
  )
  tenant_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Tenant Logs</label>
    <description></description>
    <definition>
        <![CDATA[${local.tenant_definition}]]>
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

resource "splunk_data_ui_views" "tenant" {
  name     = "tenant"
  eai_data = local.tenant_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
