locals {
  forge_kubernetes_storage_and_network_definition = templatefile(
    "${path.module}/template_files/forge_kubernetes_storage_and_network.json.tftpl",
    {
      splunk_index = var.splunk_conf.index,
      tenants      = sort(var.splunk_conf.tenant_names)
    }
  )

  forge_kubernetes_storage_and_network_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Forge Kubernetes Storage and Network</label>
    <description></description>
    <definition>
        <![CDATA[${local.forge_kubernetes_storage_and_network_definition}]]>
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

resource "splunk_data_ui_views" "forge_kubernetes_storage_and_network" {
  name     = "forge_kubernetes_storage_and_network"
  eai_data = local.forge_kubernetes_storage_and_network_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
