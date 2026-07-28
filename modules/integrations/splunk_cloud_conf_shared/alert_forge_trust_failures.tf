locals {
  forge_trust_failure_alert_search = <<-EOT
    index="${var.splunk_conf.index}" sourcetype="aws:cloudwatchlogs" source="*:/aws/lambda/*forge-trust-validator*" "Delayed validation run complete"
    | rex field=source "^[^:]+:/aws/lambda/(?<lambda_name>[^:]+):"
    | rex field=source "^[^:]+:/aws/lambda/(?<validator_tenant>[a-z0-9]+)-"
    | rex field=_raw "Delayed validation run complete: (?<trust_json>\\{.*\\})"
    | eventstats max(_time) as latest_validation by validator_tenant
    | where _time=latest_validation
    | spath input=trust_json path=validation_results{} output=result
    | mvexpand result
    | spath input=result path=forge_role_arn output=forge_role
    | spath input=result path=tenant_results{} output=tenant_result
    | mvexpand tenant_result
    | spath input=tenant_result
    | eval assume_ok=tostring(assume_role_success), tag_ok=tostring(tag_session_success)
    | where assume_ok!="true" OR tag_ok!="true"
    | table validator_tenant forge_role tenant_role_arn assume_ok assume_role_error tag_ok tag_session_error
    | sort validator_tenant forge_role tenant_role_arn
  EOT
}

resource "splunk_saved_searches" "forge_iam_trust_failures" {
  name        = "Forge IAM trust validation failures"
  description = "Tracks failed AssumeRole or TagSession edges from each tenant validator's latest completed validation. Investigate in the Forge Trust Failures dashboard."
  search      = local.forge_trust_failure_alert_search

  disabled               = false
  is_scheduled           = true
  cron_schedule          = "*/15 * * * *"
  dispatch_earliest_time = "-24h"
  dispatch_latest_time   = "now"

  actions               = ""
  alert_type            = "number of events"
  alert_comparator      = "greater than"
  alert_threshold       = "0"
  alert_digest_mode     = true
  alert_suppress        = true
  alert_suppress_period = "30m"
  alert_severity        = 5
  alert_track           = true

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
