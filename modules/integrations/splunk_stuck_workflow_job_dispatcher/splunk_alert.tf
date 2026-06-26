locals {
  splunk_webhook_url = "${aws_apigatewayv2_api.splunk.api_endpoint}/splunk/${random_password.webhook_token.result}"

  stuck_workflow_job_search = <<-EOT
    index="${var.splunk_conf.index}" ((forgecicd_log_type=webhook github.status=*) OR ("Successfully dispatched job for"))
    | rex field=message "to the queue (?<queued_url>https?://\S+)\s-\sJob ID:\s(?<dispatch_workflowJobId>\d+)"
    | spath path=github.workflowJobId output=github_workflow_job_id
    | spath path=github.workflowJobUrl output=workflow_job_url
    | spath path=github.runId output=run_id
    | spath path=github.runAttempt output=run_attempt
    | spath path=github.runUrl output=run_url
    | spath path=github.workflowName output=workflow_name
    | spath path=github.repository output=github_repository
    | spath path=github.name output=job_name
    | spath path=github.status output=status
    | spath path=github.created_at output=created_at
    | spath path=github.started_at output=started_at
    | spath path=github.labels{} output=github_labels
    | spath path=github.github-delivery output=github_delivery
    | spath path=github.headBranch output=head_branch
    | spath path=github.headSha output=head_sha
    | eval workflowJobId=coalesce(github_workflow_job_id, 'github.workflowJobId', dispatch_workflowJobId)
    | where isnotnull(workflowJobId)
    | eval repository=coalesce(github_repository, 'github.repository')
    | eval is_webhook=if(forgecicd_log_type="webhook", 1, 0)
    | eval is_queued=if(forgecicd_log_type="webhook" AND status="queued", 1, 0)
    | eval is_dispatch=if(searchmatch("Successfully dispatched job for"), 1, 0)
    | stats
        count(eval(is_webhook=1)) as total_events
        sum(is_queued) as queued_count
        max(is_dispatch) as has_dispatch
        min(_time) as first_seen
        max(_time) as last_seen
        latest(job_name) as job_name
        latest(forgecicd_tenant) as forgecicd_tenant
        latest(repository) as repository
        latest(workflow_job_url) as workflow_job_url
        latest(run_id) as run_id
        latest(run_attempt) as run_attempt
        latest(run_url) as run_url
        latest(workflow_name) as workflow_name
        latest(head_branch) as head_branch
        latest(head_sha) as head_sha
        latest(created_at) as created_at
        latest(started_at) as started_at
        values(github_labels) as labels
        values(github_delivery) as github_delivery
        latest(queued_url) as queued_url
        latest(aws_region) as aws_region
      by workflowJobId
    | where total_events = queued_count
    | where has_dispatch = 1
    | eval stuck_since=strftime(first_seen, "%Y-%m-%dT%H:%M:%S%Z"), stuck_minutes=round((now() - first_seen) / 60, 1)
    | where stuck_minutes > ${var.splunk_alert.stuck_minutes_threshold}
    | sort - stuck_minutes
    | eval splunk_batch_result=json_object("workflowJobId", workflowJobId, "job_name", job_name, "repository", repository, "workflow_job_url", workflow_job_url, "run_id", run_id, "run_attempt", run_attempt, "run_url", run_url, "workflow_name", workflow_name, "runner_labels", labels, "head_sha", head_sha, "head_branch", head_branch, "created_at", created_at, "started_at", started_at, "stuck_since", stuck_since, "stuck_minutes", stuck_minutes, "queued_url", queued_url, "github_delivery", github_delivery, "forgecicd_tenant", forgecicd_tenant, "aws_region", aws_region)
    | stats count as result_count list(splunk_batch_result) as splunk_batch_results
    | where result_count > 0
    | eval results=mv_to_json_array(splunk_batch_results, true())
    | table result_count results
  EOT
}

resource "splunk_configs_conf" "stuck_workflow_job_dispatcher" {
  name = "savedsearches/${var.splunk_alert.name}"

  variables = {
    "description"              = var.splunk_alert.description
    "search"                   = local.stuck_workflow_job_search
    "disabled"                 = tostring(var.splunk_alert.disabled)
    "is_scheduled"             = "1"
    "cron_schedule"            = var.splunk_alert.cron_schedule
    "dispatch.earliest_time"   = var.splunk_alert.dispatch_earliest_time
    "dispatch.latest_time"     = var.splunk_alert.dispatch_latest_time
    "actions"                  = "webhook"
    "action.webhook"           = "1"
    "action.webhook.param.url" = local.splunk_webhook_url
    "alert_type"               = "number of events"
    "alert_comparator"         = "greater than"
    "alert_threshold"          = "0"
    "alert.digest_mode"        = "1"
    "alert.suppress"           = "1"
    "alert.suppress.fields"    = ""
    "alert.suppress.period"    = var.splunk_alert.suppress_period
    "alert.severity"           = "4"
    "alert.track"              = "1"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    # Splunk materializes savedsearches.conf defaults that this module does not manage.
    ignore_changes = [
      variables["action.email"],
      variables["action.email.inline"],
      variables["action.email.reportIncludeSplunkLogo"],
      variables["action.email.reportServerEnabled"],
      variables["action.email.sendpdf"],
      variables["action.email.sendresults"],
      variables["action.email.track_alert"],
      variables["action.email.use_ssl"],
      variables["action.email.use_tls"],
      variables["action.email.width_sort_columns"],
      variables["action.populate_lookup"],
      variables["action.populate_lookup.track_alert"],
      variables["action.rss"],
      variables["action.rss.track_alert"],
      variables["action.script"],
      variables["action.script.track_alert"],
      variables["action.slack.param.attachment"],
      variables["action.summary_index"],
      variables["action.summary_index.force_realtime_schedule"],
      variables["action.summary_index.inline"],
      variables["action.summary_index.track_alert"],
      variables["action.victorops.param.enable_recovery"],
      variables["action.victorops.param.message_type"],
      variables["alert.expires"],
      variables["alert.managedBy"],
      variables["alert.suppress.group_name"],
      variables["alert_condition"],
      variables["allow_data_time_skew"],
      variables["allow_skew"],
      variables["auto_summarize"],
      variables["auto_summarize.command"],
      variables["auto_summarize.cron_schedule"],
      variables["auto_summarize.dispatch.earliest_time"],
      variables["auto_summarize.dispatch.latest_time"],
      variables["auto_summarize.dispatch.time_format"],
      variables["auto_summarize.dispatch.ttl"],
      variables["auto_summarize.max_concurrent"],
      variables["auto_summarize.max_disabled_buckets"],
      variables["auto_summarize.max_summary_ratio"],
      variables["auto_summarize.max_summary_size"],
      variables["auto_summarize.max_time"],
      variables["auto_summarize.suspend_period"],
      variables["auto_summarize.timespan"],
      variables["auto_summarize.workload_pool"],
      variables["calculate_alert_required_fields_in_search"],
      variables["counttype"],
      variables["defer_scheduled_searchable_idxc"],
      variables["dispatch.allow_partial_results"],
      variables["dispatch.auto_cancel"],
      variables["dispatch.auto_pause"],
      variables["dispatch.buckets"],
      variables["dispatch.index_earliest"],
      variables["dispatch.index_latest"],
      variables["dispatch.indexedRealtime"],
      variables["dispatch.indexedRealtimeMinSpan"],
      variables["dispatch.indexedRealtimeOffset"],
      variables["dispatch.lookups"],
      variables["dispatch.max_count"],
      variables["dispatch.max_time"],
      variables["dispatch.rate_limit_retry"],
      variables["dispatch.reduce_freq"],
      variables["dispatch.rt_backfill"],
      variables["dispatch.rt_maximum_span"],
      variables["dispatch.sample_ratio"],
      variables["dispatch.spawn_process"],
      variables["dispatch.time_format"],
      variables["dispatch.ttl"],
      variables["dispatchAs"],
      variables["display.events.fields"],
      variables["display.events.list.drilldown"],
      variables["display.events.list.wrap"],
      variables["display.events.maxLines"],
      variables["display.events.raw.drilldown"],
      variables["display.events.rowNumbers"],
      variables["display.events.table.drilldown"],
      variables["display.events.table.wrap"],
      variables["display.events.type"],
      variables["display.general.enablePreview"],
      variables["display.general.migratedFromViewState"],
      variables["display.general.timeRangePicker.show"],
      variables["display.general.type"],
      variables["display.page.search.mode"],
      variables["display.page.search.patterns.sensitivity"],
      variables["display.page.search.showFields"],
      variables["display.page.search.tab"],
      variables["display.page.search.timeline.format"],
      variables["display.page.search.timeline.scale"],
      variables["display.statistics.drilldown"],
      variables["display.statistics.overlay"],
      variables["display.statistics.percentagesRow"],
      variables["display.statistics.rowNumbers"],
      variables["display.statistics.show"],
      variables["display.statistics.totalsRow"],
      variables["display.statistics.wrap"],
      variables["display.visualizations.chartHeight"],
      variables["display.visualizations.charting.axisLabelsX.majorLabelStyle.overflowMode"],
      variables["display.visualizations.charting.axisLabelsX.majorLabelStyle.rotation"],
      variables["display.visualizations.charting.axisLabelsX.majorUnit"],
      variables["display.visualizations.charting.axisLabelsY.majorUnit"],
      variables["display.visualizations.charting.axisLabelsY2.majorUnit"],
      variables["display.visualizations.charting.axisTitleX.text"],
      variables["display.visualizations.charting.axisTitleX.visibility"],
      variables["display.visualizations.charting.axisTitleY.text"],
      variables["display.visualizations.charting.axisTitleY.visibility"],
      variables["display.visualizations.charting.axisTitleY2.text"],
      variables["display.visualizations.charting.axisTitleY2.visibility"],
      variables["display.visualizations.charting.axisX.abbreviation"],
      variables["display.visualizations.charting.axisX.maximumNumber"],
      variables["display.visualizations.charting.axisX.minimumNumber"],
      variables["display.visualizations.charting.axisX.scale"],
      variables["display.visualizations.charting.axisY.abbreviation"],
      variables["display.visualizations.charting.axisY.maximumNumber"],
      variables["display.visualizations.charting.axisY.minimumNumber"],
      variables["display.visualizations.charting.axisY.scale"],
      variables["display.visualizations.charting.axisY2.abbreviation"],
      variables["display.visualizations.charting.axisY2.enabled"],
      variables["display.visualizations.charting.axisY2.maximumNumber"],
      variables["display.visualizations.charting.axisY2.minimumNumber"],
      variables["display.visualizations.charting.axisY2.scale"],
      variables["display.visualizations.charting.chart"],
      variables["display.visualizations.charting.chart.bubbleMaximumSize"],
      variables["display.visualizations.charting.chart.bubbleMinimumSize"],
      variables["display.visualizations.charting.chart.bubbleSizeBy"],
      variables["display.visualizations.charting.chart.nullValueMode"],
      variables["display.visualizations.charting.chart.overlayFields"],
      variables["display.visualizations.charting.chart.rangeValues"],
      variables["display.visualizations.charting.chart.showDataLabels"],
      variables["display.visualizations.charting.chart.sliceCollapsingThreshold"],
      variables["display.visualizations.charting.chart.stackMode"],
      variables["display.visualizations.charting.chart.style"],
      variables["display.visualizations.charting.drilldown"],
      variables["display.visualizations.charting.fieldColors"],
      variables["display.visualizations.charting.fieldDashStyles"],
      variables["display.visualizations.charting.gaugeColors"],
      variables["display.visualizations.charting.layout.splitSeries"],
      variables["display.visualizations.charting.layout.splitSeries.allowIndependentYRanges"],
      variables["display.visualizations.charting.legend.labelStyle.overflowMode"],
      variables["display.visualizations.charting.legend.mode"],
      variables["display.visualizations.charting.legend.placement"],
      variables["display.visualizations.charting.lineWidth"],
      variables["display.visualizations.custom.drilldown"],
      variables["display.visualizations.custom.height"],
      variables["display.visualizations.custom.type"],
      variables["display.visualizations.mapHeight"],
      variables["display.visualizations.mapping.choroplethLayer.colorBins"],
      variables["display.visualizations.mapping.choroplethLayer.colorMode"],
      variables["display.visualizations.mapping.choroplethLayer.maximumColor"],
      variables["display.visualizations.mapping.choroplethLayer.minimumColor"],
      variables["display.visualizations.mapping.choroplethLayer.neutralPoint"],
      variables["display.visualizations.mapping.choroplethLayer.shapeOpacity"],
      variables["display.visualizations.mapping.choroplethLayer.showBorder"],
      variables["display.visualizations.mapping.data.maxClusters"],
      variables["display.visualizations.mapping.drilldown"],
      variables["display.visualizations.mapping.legend.placement"],
      variables["display.visualizations.mapping.map.center"],
      variables["display.visualizations.mapping.map.panning"],
      variables["display.visualizations.mapping.map.scrollZoom"],
      variables["display.visualizations.mapping.map.zoom"],
      variables["display.visualizations.mapping.markerLayer.markerMaxSize"],
      variables["display.visualizations.mapping.markerLayer.markerMinSize"],
      variables["display.visualizations.mapping.markerLayer.markerOpacity"],
      variables["display.visualizations.mapping.showTiles"],
      variables["display.visualizations.mapping.tileLayer.maxZoom"],
      variables["display.visualizations.mapping.tileLayer.minZoom"],
      variables["display.visualizations.mapping.tileLayer.tileOpacity"],
      variables["display.visualizations.mapping.tileLayer.url"],
      variables["display.visualizations.mapping.type"],
      variables["display.visualizations.show"],
      variables["display.visualizations.singlevalue.afterLabel"],
      variables["display.visualizations.singlevalue.beforeLabel"],
      variables["display.visualizations.singlevalue.colorBy"],
      variables["display.visualizations.singlevalue.colorMode"],
      variables["display.visualizations.singlevalue.drilldown"],
      variables["display.visualizations.singlevalue.numberPrecision"],
      variables["display.visualizations.singlevalue.rangeColors"],
      variables["display.visualizations.singlevalue.rangeValues"],
      variables["display.visualizations.singlevalue.showSparkline"],
      variables["display.visualizations.singlevalue.showTrendIndicator"],
      variables["display.visualizations.singlevalue.trendColorInterpretation"],
      variables["display.visualizations.singlevalue.trendDisplayMode"],
      variables["display.visualizations.singlevalue.trendInterval"],
      variables["display.visualizations.singlevalue.underLabel"],
      variables["display.visualizations.singlevalue.unit"],
      variables["display.visualizations.singlevalue.unitPosition"],
      variables["display.visualizations.singlevalue.useColors"],
      variables["display.visualizations.singlevalue.useThousandSeparators"],
      variables["display.visualizations.singlevalueHeight"],
      variables["display.visualizations.trellis.enabled"],
      variables["display.visualizations.trellis.scales.shared"],
      variables["display.visualizations.trellis.size"],
      variables["display.visualizations.trellis.splitBy"],
      variables["display.visualizations.type"],
      variables["displayview"],
      variables["durable.backfill_type"],
      variables["durable.lag_time"],
      variables["durable.max_backfill_intervals"],
      variables["durable.track_time_type"],
      variables["embed.enabled"],
      variables["enableSched"],
      variables["federated_providers"],
      variables["is_visible"],
      variables["max_concurrent"],
      variables["precalculate_required_fields_for_alerts"],
      variables["quantity"],
      variables["realtime_schedule"],
      variables["relation"],
      variables["request.ui_dispatch_app"],
      variables["request.ui_dispatch_view"],
      variables["restart_on_searchpeer_add"],
      variables["run_n_times"],
      variables["run_on_startup"],
      variables["schedule_as"],
      variables["schedule_priority"],
      variables["schedule_window"],
      variables["sendresults"],
      variables["skip_scheduled_realtime_idxc"],
      variables["vsid"],
      variables["workload_pool"],
    ]
  }
}
