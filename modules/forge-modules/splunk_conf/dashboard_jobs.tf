locals {
  job_definition = templatefile(
    "${path.module}/template_files/ci_jobs.json.tftpl",
    {
      splunk_index = var.splunk_conf.index
    }
  )
  job_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>CI Job Result</label>
    <description></description>
    <definition>
        <![CDATA[${local.job_definition}]]>
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

resource "splunk_data_ui_views" "ci_jobs" {
  name     = "ci_jobs"
  eai_data = local.job_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
