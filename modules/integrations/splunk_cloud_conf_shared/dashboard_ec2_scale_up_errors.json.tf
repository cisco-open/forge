locals {
  ec2_scale_up_errors_definition = templatefile(
    "${path.module}/template_files/ec2_scale_up_errors.json.tftpl",
    {
      splunk_index = var.splunk_conf.index,
      tenants      = var.splunk_conf.tenant_names
    }
  )
  ec2_scale_up_errors_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>EC2 Scale up Errors</label>
    <description></description>
    <definition>
        <![CDATA[${local.ec2_scale_up_errors_definition}]]>
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

resource "splunk_data_ui_views" "ec2_scale_up_errors" {
  name     = "ec2_scale_up_errors"
  eai_data = local.ec2_scale_up_errors_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
