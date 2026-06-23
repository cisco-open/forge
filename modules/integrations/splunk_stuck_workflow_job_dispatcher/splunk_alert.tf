locals {
  splunk_webhook_url = "${aws_apigatewayv2_api.splunk.api_endpoint}/splunk/${random_password.webhook_token.result}"

  stuck_workflow_job_search = <<-EOT
    index="${var.splunk_conf.index}" ((forgecicd_log_type=webhook github.status=*) OR ("Successfully dispatched job for"))
    | rex field=message "to the queue (?<queued_url>https?://\S+)\s-\sJob ID:\s(?<dispatch_workflowJobId>\d+)"
    | eval workflowJobId=coalesce('github.workflowJobId', dispatch_workflowJobId)
    | where isnotnull(workflowJobId)
    | eval is_webhook=if(forgecicd_log_type="webhook", 1, 0)
    | eval is_queued=if(forgecicd_log_type="webhook" AND 'github.status'="queued", 1, 0)
    | eval is_dispatch=if(searchmatch("Successfully dispatched job for"), 1, 0)
    | stats
        count(eval(is_webhook=1)) as total_events
        sum(is_queued) as queued_count
        max(is_dispatch) as has_dispatch
        min(_time) as first_seen
        max(_time) as last_seen
        latest(github.name) as job_name
        latest(forgecicd_tenant) as forgecicd_tenant
        latest(github.repository) as repository
        latest(github.started_at) as started_at
        latest(aws_region) as aws_region
        latest(forgecicd_region_alias) as forgecicd_region_alias
        latest(forgecicd_vpc_alias) as forgecicd_vpc_alias
        values(github.labels) as labels
        values(github.github-delivery) as github_deliveries
        values(queued_url) as queued_url
      by workflowJobId
    | where total_events = queued_count
    | where has_dispatch = 1
    | eval stuck_since=strftime(first_seen, "%Y-%m-%dT%H:%M:%S%Z"), stuck_minutes=round((now() - first_seen) / 60, 1)
    | where stuck_minutes > ${var.splunk_alert.stuck_minutes_threshold}
    | sort - stuck_minutes
    | table workflowJobId job_name repository labels started_at stuck_since stuck_minutes queued_url github_deliveries forgecicd_tenant aws_region forgecicd_region_alias forgecicd_vpc_alias
  EOT
}

resource "splunk_saved_searches" "stuck_workflow_job_dispatcher" {
  name        = var.splunk_alert.name
  description = var.splunk_alert.description
  search      = local.stuck_workflow_job_search

  disabled      = var.splunk_alert.disabled
  is_scheduled  = true
  cron_schedule = var.splunk_alert.cron_schedule

  dispatch_earliest_time = var.splunk_alert.dispatch_earliest_time
  dispatch_latest_time   = var.splunk_alert.dispatch_latest_time

  actions                  = "webhook"
  action_webhook_param_url = local.splunk_webhook_url

  alert_type            = "number of events"
  alert_comparator      = "greater than"
  alert_threshold       = "0"
  alert_digest_mode     = false
  alert_suppress        = true
  alert_suppress_fields = "workflowJobId"
  alert_suppress_period = var.splunk_alert.suppress_period
  alert_severity        = 4
  alert_track           = "true"

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
