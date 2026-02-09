locals {
  trust_relationship_validation_definition = templatefile(
    "${path.module}/template_files/trust_relationship_validation.json.tftpl",
    {
      splunk_index = var.splunk_conf.index,
      tenants      = var.splunk_conf.tenant_names
    }
  )
  trust_relationship_validation_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Trust Relationship Validation</label>
    <description></description>
    <definition>
        <![CDATA[${local.trust_relationship_validation_definition}]]>
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

resource "splunk_data_ui_views" "trust_relationship_validation" {
  name     = "trust_relationship_validation"
  eai_data = local.trust_relationship_validation_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
