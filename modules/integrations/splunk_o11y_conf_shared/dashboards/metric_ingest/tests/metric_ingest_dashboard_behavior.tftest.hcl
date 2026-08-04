mock_provider "signalfx" {
  mock_resource "signalfx_time_chart" {
    defaults = {
      id = "time-chart-id"
    }
  }
  mock_resource "signalfx_list_chart" {
    defaults = {
      id = "list-chart-id"
    }
  }
  mock_resource "signalfx_dashboard" {}
}

variables {
  dashboard_group = "forge-dashboard-group"
  token_ids = [
    "ForgeProdToken02",
    "ForgeDevToken01",
    "ForgeSharedToken03",
  ]
}

run "creates_metric_ingest_dashboard" {
  command = plan

  assert {
    condition = (
      signalfx_dashboard.metric_ingest.name == "Forge Metric API Ingestion Health"
      && signalfx_dashboard.metric_ingest.dashboard_group == "forge-dashboard-group"
      && signalfx_dashboard.metric_ingest.time_range == "-1h"
      && length(signalfx_dashboard.metric_ingest.chart) == 9
      && length([for chart in signalfx_dashboard.metric_ingest.chart : chart if chart.chart_id == "time-chart-id"]) == 8
      && length([for chart in signalfx_dashboard.metric_ingest.chart : chart if chart.chart_id == "list-chart-id"]) == 1
      && length([for chart in signalfx_dashboard.metric_ingest.chart : chart if chart.chart_id == "time-chart-id" && chart.row == 0 && chart.column == 0 && chart.width == 12 && chart.height == 2]) == 1
      && length([for chart in signalfx_dashboard.metric_ingest.chart : chart if chart.chart_id == "time-chart-id" && chart.row == 5 && chart.column == 0 && chart.width == 12 && chart.height == 1]) == 1
      && length([for chart in signalfx_dashboard.metric_ingest.chart : chart if chart.chart_id == "list-chart-id" && chart.row == 6 && chart.column == 0 && chart.width == 12 && chart.height == 2]) == 1
    )
    error_message = "The metric-ingest dashboard must keep its name, parent group, one-hour range, full-width problem overview, seven detailed time charts, and one token-usage list chart."
  }

  assert {
    condition = (
      signalfx_time_chart.problem_overview.plot_type == "LineChart"
      && signalfx_time_chart.ingest_volume.plot_type == "LineChart"
      && signalfx_time_chart.payload_bytes.plot_type == "AreaChart"
      && signalfx_time_chart.datapoint_drops.plot_type == "ColumnChart"
      && signalfx_time_chart.mts_admission.plot_type == "ColumnChart"
      && signalfx_time_chart.metric_type_backfill.plot_type == "AreaChart"
      && signalfx_time_chart.metadata_rest.plot_type == "LineChart"
      && signalfx_time_chart.cloudwatch_metric_stream.plot_type == "ColumnChart"
      && signalfx_list_chart.usage_objects.name == "Metric usage and objects by token"
      && toset([for field in signalfx_time_chart.problem_overview.legend_options_fields : field.property]) == toset([
        "tokenName",
        "tokenId",
      ])
      && alltrue([
        for chart in [
          signalfx_time_chart.ingest_volume,
          signalfx_time_chart.payload_bytes,
          signalfx_time_chart.datapoint_drops,
          signalfx_time_chart.mts_admission,
          signalfx_time_chart.metric_type_backfill,
          signalfx_time_chart.metadata_rest,
          signalfx_time_chart.cloudwatch_metric_stream,
        ] : contains(toset([for field in chart.legend_options_fields : field.property]), "sf_originatingMetric")
      ])
      && contains(toset([for field in signalfx_list_chart.usage_objects.legend_options_fields : field.property]), "sf_originatingMetric")
    )
    error_message = "Metric-ingest diagnostics must retain the intended line, area, column, and list visualizations."
  }

  assert {
    condition = (
      signalfx_time_chart.problem_overview.name == "Metric ingest problems and archived volume by token"
      && strcontains(signalfx_time_chart.problem_overview.description, "not a deduplicated loss total")
      && strcontains(signalfx_time_chart.problem_overview.description, "Archived datapoints are routing context on the right axis, not rejected datapoints")
      && length(regexall(
        "sf\\.org\\.[A-Za-z0-9.]+[Bb]yToken",
        signalfx_time_chart.problem_overview.program_text,
      )) == 11
      && toset(regexall(
        "sf\\.org\\.[A-Za-z0-9.]+[Bb]yToken",
        signalfx_time_chart.problem_overview.program_text,
        )) == toset([
        "sf.org.cloud.numDatapointsDroppedOversizeByToken",
        "sf.org.cloud.numDatapointsDroppedThrottleByToken",
        "sf.org.numAggregatedDatapointsDroppedThrottleByToken",
        "sf.org.numArchivedDatapointsReceivedByToken",
        "sf.org.numDatapointsDroppedBatchSizeByToken",
        "sf.org.numDatapointsDroppedExceededQuotaByToken",
        "sf.org.numDatapointsDroppedInTimeoutByToken",
        "sf.org.numDatapointsDroppedInvalidByToken",
        "sf.org.numDatapointsDroppedMetricRulesetByToken",
        "sf.org.numDatapointsDroppedThrottleByToken",
        "sf.org.numLimitedMetricTimeSeriesCreateCallsByToken",
      ])
      && length(regexall("\\.publish\\(label='[A-D]'\\)", signalfx_time_chart.problem_overview.program_text)) == 4
      && length(regexall("extrapolation='zero'", signalfx_time_chart.problem_overview.program_text)) == 11
      && length([for axis in signalfx_time_chart.problem_overview.axis_left : axis if axis.label == "Drop / admission problem signals" && axis.min_value == 0]) == 1
      && length([for axis in signalfx_time_chart.problem_overview.axis_right : axis if axis.label == "Archived datapoints" && axis.min_value == 0]) == 1
      && length([for option in signalfx_time_chart.problem_overview.viz_options : option if option.label == "A" && option.axis == "right" && option.color == "blue" && option.display_name == "Archived datapoints (context)"]) == 1
      && length([for option in signalfx_time_chart.problem_overview.viz_options : option if option.label == "B" && option.axis == "left" && option.color == "red" && option.display_name == "Direct datapoint drops"]) == 1
      && length([for option in signalfx_time_chart.problem_overview.viz_options : option if option.label == "C" && option.axis == "left" && option.color == "orange" && option.display_name == "MTS creation limit calls"]) == 1
      && length([for option in signalfx_time_chart.problem_overview.viz_options : option if option.label == "D" && option.axis == "left" && option.color == "purple" && option.display_name == "CloudWatch Metric Stream drops"]) == 1
    )
    error_message = "The problem overview must keep archived volume separate from direct drops, generic MTS creation limits, and CloudWatch drops while preserving detailed drill-down semantics."
  }

  assert {
    condition = (
      length(var.token_ids) == 3
      && length(toset(var.token_ids)) == 3
      && length(signalfx_dashboard.metric_ingest.variable) == 1
      && signalfx_dashboard.metric_ingest.variable[0].property == "tokenId"
      && signalfx_dashboard.metric_ingest.variable[0].alias == "Token ID"
      && signalfx_dashboard.metric_ingest.variable[0].values_suggested == toset(var.token_ids)
      && !signalfx_dashboard.metric_ingest.variable[0].value_required
      && signalfx_dashboard.metric_ingest.variable[0].restricted_suggestions
      && signalfx_dashboard.metric_ingest.variable[0].replace_only
      && alltrue([
        for program_text in [
          signalfx_time_chart.problem_overview.program_text,
          signalfx_time_chart.ingest_volume.program_text,
          signalfx_time_chart.payload_bytes.program_text,
          signalfx_time_chart.datapoint_drops.program_text,
          signalfx_time_chart.mts_admission.program_text,
          signalfx_time_chart.metric_type_backfill.program_text,
          signalfx_time_chart.metadata_rest.program_text,
          signalfx_time_chart.cloudwatch_metric_stream.program_text,
          signalfx_list_chart.usage_objects.program_text,
          ] : strcontains(program_text, "filter('tokenId', 'ForgeDevToken01', 'ForgeProdToken02', 'ForgeSharedToken03')") && alltrue([
            for token_id in var.token_ids : strcontains(program_text, "'${token_id}'")
        ]) && !strcontains(program_text, "__forge_metric_ingest_scope_not_configured__")
      ])
    )
    error_message = "The token selector and every token chart must interpolate, sort, and restrict queries to the configured owned token IDs."
  }

  assert {
    condition = (
      alltrue([
        for chart in [
          signalfx_time_chart.problem_overview,
          signalfx_time_chart.ingest_volume,
          signalfx_time_chart.payload_bytes,
          signalfx_time_chart.datapoint_drops,
          signalfx_time_chart.mts_admission,
          signalfx_time_chart.metric_type_backfill,
          signalfx_time_chart.metadata_rest,
          signalfx_time_chart.cloudwatch_metric_stream,
        ] : chart.axes_include_zero
        && chart.axes_precision == 0
        && chart.disable_sampling
        && chart.on_chart_legend_dimension == "plot_label"
        && chart.time_range == 3600
      ])
      && length(regexall("rollup='sum'", join("\n", [
        signalfx_time_chart.problem_overview.program_text,
        signalfx_time_chart.ingest_volume.program_text,
        signalfx_time_chart.payload_bytes.program_text,
        signalfx_time_chart.datapoint_drops.program_text,
        signalfx_time_chart.mts_admission.program_text,
        signalfx_time_chart.metric_type_backfill.program_text,
        signalfx_time_chart.metadata_rest.program_text,
        signalfx_time_chart.cloudwatch_metric_stream.program_text,
      ]))) == 54
      && length(regexall("rollup='max'", signalfx_list_chart.usage_objects.program_text)) == 18
      && signalfx_list_chart.usage_objects.max_precision == 0
    )
    error_message = "Time-series counters must use unsampled one-hour sum charts from zero, and token-usage gauges must use max rollups."
  }

  assert {
    condition = (
      length(regexall(
        "sf\\.org\\.[A-Za-z0-9.]+[Bb]yToken",
        join("\n", [
          signalfx_time_chart.ingest_volume.program_text,
          signalfx_time_chart.payload_bytes.program_text,
          signalfx_time_chart.datapoint_drops.program_text,
          signalfx_time_chart.mts_admission.program_text,
          signalfx_time_chart.metric_type_backfill.program_text,
          signalfx_time_chart.metadata_rest.program_text,
          signalfx_time_chart.cloudwatch_metric_stream.program_text,
          signalfx_list_chart.usage_objects.program_text,
        ]),
      )) == 61
      && length(toset(regexall(
        "sf\\.org\\.[A-Za-z0-9.]+[Bb]yToken",
        join("\n", [
          signalfx_time_chart.ingest_volume.program_text,
          signalfx_time_chart.payload_bytes.program_text,
          signalfx_time_chart.datapoint_drops.program_text,
          signalfx_time_chart.mts_admission.program_text,
          signalfx_time_chart.metric_type_backfill.program_text,
          signalfx_time_chart.metadata_rest.program_text,
          signalfx_time_chart.cloudwatch_metric_stream.program_text,
          signalfx_list_chart.usage_objects.program_text,
        ]),
      ))) == 61
      && toset(regexall(
        "sf\\.org\\.[A-Za-z0-9.]+[Bb]yToken",
        join("\n", [
          signalfx_time_chart.ingest_volume.program_text,
          signalfx_time_chart.payload_bytes.program_text,
          signalfx_time_chart.datapoint_drops.program_text,
          signalfx_time_chart.mts_admission.program_text,
          signalfx_time_chart.metric_type_backfill.program_text,
          signalfx_time_chart.metadata_rest.program_text,
          signalfx_time_chart.cloudwatch_metric_stream.program_text,
          signalfx_list_chart.usage_objects.program_text,
        ]),
        )) == toset([
        "sf.org.cloud.datapointsTotalCountByToken",
        "sf.org.cloud.numCwMetricStreamCallsByToken",
        "sf.org.cloud.numDatapointsDroppedOversizeByToken",
        "sf.org.cloud.numDatapointsDroppedThrottleByToken",
        "sf.org.datapointsTotalCollectdByToken",
        "sf.org.datapointsTotalCountByToken",
        "sf.org.grossAggregatedDatapointsReceivedByToken",
        "sf.org.grossArchivedDatapointsReceivedByToken",
        "sf.org.grossDatapointsReceivedByToken",
        "sf.org.grossDpmBytesReceivedByToken",
        "sf.org.grossDpmContentBytesReceivedByToken",
        "sf.org.numAddDatapointCallsByToken",
        "sf.org.numAggregatedDatapointsDroppedThrottleByToken",
        "sf.org.numApmBundledMetricsByToken",
        "sf.org.numArchivedCustomMetricsByToken",
        "sf.org.numArchivedDatapointsReceivedByToken",
        "sf.org.numArchivedHistogramCustomMetricsByToken",
        "sf.org.numBackfillCallsByToken",
        "sf.org.numBadDimensionMetricTimeSeriesCreateCallsByToken",
        "sf.org.numBadMetricMetricTimeSeriesCreateCallsByToken",
        "sf.org.numBillableArchivedCustomMetricsByToken",
        "sf.org.numBillableArchivedHistogramCustomMetricsByToken",
        "sf.org.numCustomMetricsByToken",
        "sf.org.numDatapointsBackfilledByToken",
        "sf.org.numDatapointsDroppedBatchSizeByToken",
        "sf.org.numDatapointsDroppedExceededQuotaByToken",
        "sf.org.numDatapointsDroppedInTimeoutByToken",
        "sf.org.numDatapointsDroppedInvalidByToken",
        "sf.org.numDatapointsDroppedMetricRulesetByToken",
        "sf.org.numDatapointsDroppedThrottleByToken",
        "sf.org.numDatapointsReceivedByMetricTypeByToken",
        "sf.org.numDatapointsReceivedByToken",
        "sf.org.numDimensionObjectsCreatedByToken",
        "sf.org.numEntityEventsDroppedThrottleByToken",
        "sf.org.numEntityEventsReceivedByToken",
        "sf.org.numHighResolutionMetricsByToken",
        "sf.org.numHistogramApmBundledMetricsByToken",
        "sf.org.numHistogramCustomMetricsByToken",
        "sf.org.numHostMetaDataEventsDroppedThrottleByToken",
        "sf.org.numLimitedMetricTimeSeriesCreateCallsByCategoryTypeByToken",
        "sf.org.numLimitedMetricTimeSeriesCreateCallsByToken",
        "sf.org.numMappingsAddedByToken",
        "sf.org.numMetadataWritesByToken",
        "sf.org.numMetadataWritesThrottledByToken",
        "sf.org.numMetricObjectsCreatedByToken",
        "sf.org.numMetricTimeSeriesCreatedByCategoryTypeByToken",
        "sf.org.numMetricTimeSeriesCreatedByDatapointTypeByToken",
        "sf.org.numMetricTimeSeriesCreatedByToken",
        "sf.org.numNpmMetricsByToken",
        "sf.org.numProcessDataEventsDroppedThrottleByToken",
        "sf.org.numPropertyLimitedMetricTimeSeriesCreateCallsByToken",
        "sf.org.numRealTimeCustomMetricsByToken",
        "sf.org.numReceivedDatapointsAggregatedByToken",
        "sf.org.numResourceMetricsbyToken",
        "sf.org.numResourcesMonitoredByToken",
        "sf.org.numRestCallsThrottledByToken",
        "sf.org.numRumMonitoringMetricSetMetricsByToken",
        "sf.org.numSyntheticsMetricsByToken",
        "sf.org.numThrottledMetricTimeSeriesCreateCallsByDatapointTypeByToken",
        "sf.org.numThrottledMetricTimeSeriesCreateCallsByToken",
        "sf.org.usageBySubscriptionType.numResourcesMonitoredByToken",
      ])
    )
    error_message = "The eight detailed token-scoped charts must contain the exact inventory of sixty-one unique API and metric-ingest ByToken metrics."
  }
}

run "empty_token_scope_fails_closed" {
  command = plan

  variables {
    token_ids = []
  }

  assert {
    condition = (
      length(signalfx_dashboard.metric_ingest.variable[0].values_suggested) == 0
      && alltrue([
        for program_text in [
          signalfx_time_chart.problem_overview.program_text,
          signalfx_time_chart.ingest_volume.program_text,
          signalfx_time_chart.payload_bytes.program_text,
          signalfx_time_chart.datapoint_drops.program_text,
          signalfx_time_chart.mts_admission.program_text,
          signalfx_time_chart.metric_type_backfill.program_text,
          signalfx_time_chart.metadata_rest.program_text,
          signalfx_time_chart.cloudwatch_metric_stream.program_text,
          signalfx_list_chart.usage_objects.program_text,
        ] : strcontains(program_text, "filter('tokenId', '__forge_metric_ingest_scope_not_configured__')")
      ])
    )
    error_message = "An empty token configuration must fail closed in the dashboard selector and every chart program."
  }
}

run "rejects_duplicate_token_ids" {
  command = plan

  variables {
    token_ids = ["ForgeDevToken01", "ForgeDevToken01"]
  }

  expect_failures = [var.token_ids]
}

run "rejects_invalid_token_ids" {
  command = plan

  variables {
    token_ids = ["not a token id"]
  }

  expect_failures = [var.token_ids]
}
