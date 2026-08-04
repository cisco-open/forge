locals {
  token_ids      = sort(var.token_ids)
  ingest_sources = sort(var.ingest_sources)

  token_filter  = length(local.token_ids) > 0 ? "filter('tokenId', '${join("', '", local.token_ids)}')" : "filter('tokenId', '__forge_metric_ingest_scope_not_configured__')"
  source_filter = length(local.ingest_sources) > 0 ? "filter('forgecicd_ingest_source', '${join("', '", local.ingest_sources)}')" : "filter('forgecicd_ingest_source', '__forge_metric_ingest_source_scope_not_configured__')"
}

resource "signalfx_time_chart" "problem_overview" {
  name        = "Metric ingest problems and archived volume by token"
  description = "Focused token-scoped overview. Direct datapoint drops, MTS creation limit calls, and CloudWatch Metric Stream drops are diagnostic categories, not a deduplicated loss total. Archived datapoints are routing context on the right axis, not rejected datapoints. Select one Token ID, then use the detailed charts below for exact MTS admission and drop reasons."

  program_text = <<-EOF
archived = data('sf.org.numArchivedDatapointsReceivedByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName']).publish(label='A')

aggregated_throttle = data('sf.org.numAggregatedDatapointsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
batch_size = data('sf.org.numDatapointsDroppedBatchSizeByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
exceeded_quota = data('sf.org.numDatapointsDroppedExceededQuotaByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
invalid = data('sf.org.numDatapointsDroppedInvalidByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
timeout = data('sf.org.numDatapointsDroppedInTimeoutByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
throttle = data('sf.org.numDatapointsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
metric_ruleset = data('sf.org.numDatapointsDroppedMetricRulesetByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
direct_drops = sum(aggregated_throttle, batch_size, exceeded_quota, invalid, timeout, throttle, metric_ruleset).publish(label='B')

mts_limited = data('sf.org.numLimitedMetricTimeSeriesCreateCallsByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName']).publish(label='C')

cloud_throttle = data('sf.org.cloud.numDatapointsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
cloud_oversize = data('sf.org.cloud.numDatapointsDroppedOversizeByToken', filter=(${local.token_filter}), rollup='sum', extrapolation='zero').sum(by=['tokenId', 'tokenName'])
cloud_drops = sum(cloud_throttle, cloud_oversize).publish(label='D')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  axis_left {
    label     = "Drop / admission problem signals"
    min_value = 0
  }

  axis_right {
    label     = "Archived datapoints"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }

  viz_options {
    axis         = "right"
    color        = "blue"
    display_name = "Archived datapoints (context)"
    label        = "A"
  }
  viz_options {
    axis         = "left"
    color        = "red"
    display_name = "Direct datapoint drops"
    label        = "B"
  }
  viz_options {
    axis         = "left"
    color        = "orange"
    display_name = "MTS creation limit calls"
    label        = "C"
  }
  viz_options {
    axis         = "left"
    color        = "purple"
    display_name = "CloudWatch Metric Stream drops"
    label        = "D"
  }
}

resource "signalfx_time_chart" "ingest_volume" {
  name        = "Metric API ingest volume by token"
  description = "API calls and datapoint admission volume for Forge-owned ingest tokens. Gross received is an internal supporting signal; token-level values do not prove ownership of an organization-wide limit. Use Token ID to isolate one sender."

  program_text = <<-EOF
api_calls = data('sf.org.numAddDatapointCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='A')
total_datapoints = data('sf.org.datapointsTotalCountByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='B')
collectd_datapoints = data('sf.org.datapointsTotalCollectdByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='C')
gross_received = data('sf.org.grossDatapointsReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='D')
received = data('sf.org.numDatapointsReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='E')
aggregated_received = data('sf.org.numReceivedDatapointsAggregatedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='F')
gross_aggregated = data('sf.org.grossAggregatedDatapointsReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='G')
archived_received = data('sf.org.numArchivedDatapointsReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='H')
gross_archived = data('sf.org.grossArchivedDatapointsReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='I')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "API calls"
    label        = "A"
  }
  viz_options {
    display_name = "Total datapoints"
    label        = "B"
  }
  viz_options {
    display_name = "Collectd datapoints"
    label        = "C"
  }
  viz_options {
    display_name = "Gross received (internal)"
    label        = "D"
  }
  viz_options {
    display_name = "Received / processed"
    label        = "E"
  }
  viz_options {
    display_name = "Received aggregated"
    label        = "F"
  }
  viz_options {
    display_name = "Gross aggregated"
    label        = "G"
  }
  viz_options {
    display_name = "Archived received"
    label        = "H"
  }
  viz_options {
    display_name = "Gross archived received"
    label        = "I"
  }
}

resource "signalfx_time_chart" "payload_bytes" {
  name        = "Metric API ingest payload bytes by token"
  description = "Payload-byte volume for Forge-owned metric-ingest tokens. Compare content bytes with total received bytes to detect transport overhead or unexpected payload growth."

  program_text = <<-EOF
content_bytes = data('sf.org.grossDpmContentBytesReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='A')
total_bytes = data('sf.org.grossDpmBytesReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='B')
EOF

  plot_type                 = "AreaChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  axis_left {
    label = "Bytes"
  }

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "DPM content bytes"
    label        = "A"
    value_unit   = "Byte"
  }
  viz_options {
    display_name = "DPM total bytes"
    label        = "B"
    value_unit   = "Byte"
  }
}

resource "signalfx_time_chart" "datapoint_drops" {
  name        = "Metric datapoint drops by reason and token"
  description = "Direct Infrastructure Monitoring datapoint drop reasons for Forge-owned tokens. Timeout means Splunk did not attempt points after recent account limiting; it is not a client network timeout and does not prove this token caused the organization-level limit."

  program_text = <<-EOF
aggregated_throttle = data('sf.org.numAggregatedDatapointsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='A')
batch_size = data('sf.org.numDatapointsDroppedBatchSizeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='B')
exceeded_quota = data('sf.org.numDatapointsDroppedExceededQuotaByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='C')
invalid = data('sf.org.numDatapointsDroppedInvalidByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='D')
timeout = data('sf.org.numDatapointsDroppedInTimeoutByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='E')
throttle = data('sf.org.numDatapointsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='F')
metric_ruleset = data('sf.org.numDatapointsDroppedMetricRulesetByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='G')
EOF

  plot_type                 = "ColumnChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "Aggregated throttle"
    label        = "A"
  }
  viz_options {
    display_name = "Batch size"
    label        = "B"
  }
  viz_options {
    display_name = "Exceeded quota"
    label        = "C"
  }
  viz_options {
    display_name = "Invalid"
    label        = "D"
  }
  viz_options {
    display_name = "Timeout / prior limit (internal)"
    label        = "E"
  }
  viz_options {
    display_name = "Throttle"
    label        = "F"
  }
  viz_options {
    display_name = "Metric ruleset"
    label        = "G"
  }
}

resource "signalfx_time_chart" "mts_admission" {
  name        = "Metric time-series admission by token"
  description = "Metric time-series creation, limitation, validation, and throttling signals for Forge-owned tokens. Category, categoryType, and datapointType identify which admission path is affected."

  program_text = <<-EOF
mts_created = data('sf.org.numMetricTimeSeriesCreatedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'category']).publish(label='A')
mts_limited = data('sf.org.numLimitedMetricTimeSeriesCreateCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'category']).publish(label='B')
bad_dimension = data('sf.org.numBadDimensionMetricTimeSeriesCreateCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='C')
bad_metric = data('sf.org.numBadMetricMetricTimeSeriesCreateCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='D')
property_limited = data('sf.org.numPropertyLimitedMetricTimeSeriesCreateCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='E')
mts_throttled = data('sf.org.numThrottledMetricTimeSeriesCreateCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='F')
mts_created_category_type = data('sf.org.numMetricTimeSeriesCreatedByCategoryTypeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'categoryType']).publish(label='G')
mts_limited_category_type = data('sf.org.numLimitedMetricTimeSeriesCreateCallsByCategoryTypeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'categoryType']).publish(label='H')
mts_created_datapoint_type = data('sf.org.numMetricTimeSeriesCreatedByDatapointTypeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'datapointType']).publish(label='I')
mts_throttled_datapoint_type = data('sf.org.numThrottledMetricTimeSeriesCreateCallsByDatapointTypeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'datapointType']).publish(label='J')
EOF

  plot_type                 = "ColumnChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "category"
  }
  legend_options_fields {
    enabled  = true
    property = "categoryType"
  }
  legend_options_fields {
    enabled  = true
    property = "datapointType"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "MTS created"
    label        = "A"
  }
  viz_options {
    display_name = "MTS limited"
    label        = "B"
  }
  viz_options {
    display_name = "Bad dimension"
    label        = "C"
  }
  viz_options {
    display_name = "Bad metric"
    label        = "D"
  }
  viz_options {
    display_name = "Property limited"
    label        = "E"
  }
  viz_options {
    display_name = "MTS throttled"
    label        = "F"
  }
  viz_options {
    display_name = "MTS created by category type"
    label        = "G"
  }
  viz_options {
    display_name = "MTS limited by category type"
    label        = "H"
  }
  viz_options {
    display_name = "MTS created by datapoint type"
    label        = "I"
  }
  viz_options {
    display_name = "MTS throttled by datapoint type"
    label        = "J"
  }
}

resource "signalfx_time_chart" "metric_type_backfill" {
  name        = "Metric type and backfill ingest by token"
  description = "Accepted datapoints split by metric type plus backfill calls and datapoints. Use metricType and category to distinguish normal ingestion from backfill paths."

  program_text = <<-EOF
received_metric_type = data('sf.org.numDatapointsReceivedByMetricTypeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'metricType']).publish(label='A')
backfill_calls = data('sf.org.numBackfillCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'category']).publish(label='B')
datapoints_backfilled = data('sf.org.numDatapointsBackfilledByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName', 'category']).publish(label='C')
EOF

  plot_type                 = "AreaChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "metricType"
  }
  legend_options_fields {
    enabled  = true
    property = "category"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "Received by metric type"
    label        = "A"
  }
  viz_options {
    display_name = "Backfill calls"
    label        = "B"
  }
  viz_options {
    display_name = "Datapoints backfilled"
    label        = "C"
  }
}

resource "signalfx_time_chart" "metadata_rest" {
  name        = "Metric metadata and REST throttling by token"
  description = "Metadata writes, mappings, REST throttles, and host, process, or entity event delivery for Forge-owned ingest tokens. Spikes here can explain incomplete metadata even when metric datapoints are accepted."

  program_text = <<-EOF
metadata_writes = data('sf.org.numMetadataWritesByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='A')
metadata_throttled = data('sf.org.numMetadataWritesThrottledByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='B')
mappings_added = data('sf.org.numMappingsAddedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='C')
host_metadata_dropped = data('sf.org.numHostMetaDataEventsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='D')
process_data_dropped = data('sf.org.numProcessDataEventsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='E')
entity_events_dropped = data('sf.org.numEntityEventsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='F')
entity_events_received = data('sf.org.numEntityEventsReceivedByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='G')
rest_throttled = data('sf.org.numRestCallsThrottledByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='H')
EOF

  plot_type                 = "LineChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "Metadata writes"
    label        = "A"
  }
  viz_options {
    display_name = "Metadata writes throttled"
    label        = "B"
  }
  viz_options {
    display_name = "Mappings added"
    label        = "C"
  }
  viz_options {
    display_name = "Host metadata dropped throttle"
    label        = "D"
  }
  viz_options {
    display_name = "Process data dropped throttle"
    label        = "E"
  }
  viz_options {
    display_name = "Entity events dropped throttle"
    label        = "F"
  }
  viz_options {
    display_name = "Entity events received"
    label        = "G"
  }
  viz_options {
    display_name = "REST calls throttled"
    label        = "H"
  }
}

resource "signalfx_time_chart" "cloudwatch_metric_stream" {
  name        = "CloudWatch Metric Stream ingest by token"
  description = "Cloud integration datapoints, Metric Stream calls, throttle drops, and oversize drops for Forge-owned tokens. These signals apply to AWS Metric Stream ingestion, not direct SignalFx API senders."

  program_text = <<-EOF
cloud_datapoints = data('sf.org.cloud.datapointsTotalCountByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='A')
metric_stream_calls = data('sf.org.cloud.numCwMetricStreamCallsByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='B')
cloud_throttle = data('sf.org.cloud.numDatapointsDroppedThrottleByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='C')
cloud_oversize = data('sf.org.cloud.numDatapointsDroppedOversizeByToken', filter=(${local.token_filter}), rollup='sum').sum(by=['tokenId', 'tokenName']).publish(label='D')
EOF

  plot_type                 = "ColumnChart"
  axes_include_zero         = true
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "plot_label"
  time_range                = 3600

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "Cloud datapoints"
    label        = "A"
  }
  viz_options {
    display_name = "CW Metric Stream calls"
    label        = "B"
  }
  viz_options {
    display_name = "Cloud dropped throttle"
    label        = "C"
  }
  viz_options {
    display_name = "Cloud dropped oversize"
    label        = "D"
  }
}

resource "signalfx_list_chart" "usage_objects" {
  name        = "Metric usage and objects by token"
  description = "Latest usage and object gauges attributed to Forge-owned tokens, including custom, high-resolution, histogram, archived, metric, dimension, resource, RUM, synthetics, and NPM counts. Use Token ID to narrow the table."

  program_text = <<-EOF
custom_metrics = data('sf.org.numCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='A')
high_resolution = data('sf.org.numHighResolutionMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='B')
apm_bundled = data('sf.org.numApmBundledMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='C')
histogram_custom = data('sf.org.numHistogramCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='D')
archived_custom = data('sf.org.numArchivedCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='E')
billable_archived_custom = data('sf.org.numBillableArchivedCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='F')
archived_histogram = data('sf.org.numArchivedHistogramCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='G')
billable_archived_histogram = data('sf.org.numBillableArchivedHistogramCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='H')
metric_objects = data('sf.org.numMetricObjectsCreatedByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='I')
dimension_objects = data('sf.org.numDimensionObjectsCreatedByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='J')
resources_monitored = data('sf.org.numResourcesMonitoredByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName', 'resourceType']).publish(label='K')
histogram_apm_bundled = data('sf.org.numHistogramApmBundledMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='L')
npm_metrics = data('sf.org.numNpmMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='M')
real_time_custom = data('sf.org.numRealTimeCustomMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='N')
resource_metrics = data('sf.org.numResourceMetricsbyToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName', 'resourceType']).publish(label='O')
rum_metric_sets = data('sf.org.numRumMonitoringMetricSetMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='P')
synthetics_metrics = data('sf.org.numSyntheticsMetricsByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName']).publish(label='Q')
resources_by_subscription = data('sf.org.usageBySubscriptionType.numResourcesMonitoredByToken', filter=(${local.token_filter}), rollup='max').max(by=['tokenId', 'tokenName', 'subscriptionType']).publish(label='R')
EOF

  sort_by                 = "-value"
  hide_missing_values     = false
  max_precision           = 0
  secondary_visualization = "Sparkline"
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "tokenName"
  }
  legend_options_fields {
    enabled  = true
    property = "tokenId"
  }
  legend_options_fields {
    enabled  = true
    property = "resourceType"
  }
  legend_options_fields {
    enabled  = true
    property = "subscriptionType"
  }
  legend_options_fields {
    enabled  = true
    property = "sf_originatingMetric"
  }

  viz_options {
    display_name = "Custom metrics"
    label        = "A"
  }
  viz_options {
    display_name = "High-resolution metrics"
    label        = "B"
  }
  viz_options {
    display_name = "APM-bundled metrics"
    label        = "C"
  }
  viz_options {
    display_name = "Histogram custom metrics"
    label        = "D"
  }
  viz_options {
    display_name = "Archived custom metrics"
    label        = "E"
  }
  viz_options {
    display_name = "Billable archived custom metrics"
    label        = "F"
  }
  viz_options {
    display_name = "Archived histogram custom metrics"
    label        = "G"
  }
  viz_options {
    display_name = "Billable archived histogram custom metrics"
    label        = "H"
  }
  viz_options {
    display_name = "Metric objects"
    label        = "I"
  }
  viz_options {
    display_name = "Dimension objects"
    label        = "J"
  }
  viz_options {
    display_name = "Resources monitored"
    label        = "K"
  }
  viz_options {
    display_name = "Histogram APM-bundled metrics"
    label        = "L"
  }
  viz_options {
    display_name = "NPM metrics"
    label        = "M"
  }
  viz_options {
    display_name = "Real-time custom metrics"
    label        = "N"
  }
  viz_options {
    display_name = "Resource metrics"
    label        = "O"
  }
  viz_options {
    display_name = "RUM metric-set metrics"
    label        = "P"
  }
  viz_options {
    display_name = "Synthetics metrics"
    label        = "Q"
  }
  viz_options {
    display_name = "Resources by subscription type"
    label        = "R"
  }
}

resource "signalfx_list_chart" "retained_metrics_by_source" {
  name        = "Metric names by ingest source"
  description = "Distinct retained MTS that reported at least once in the dashboard window, grouped by exact metric name and forgecicd_ingest_source. This is source attribution, not token attribution; rejected-before-retention metrics cannot appear. Narrow Ingest source when the list exceeds the chart display limit."

  program_text = <<-EOF
A = data('*', filter=(${local.source_filter}), rollup='latest').dimensions(aliases={'metric_name': 'sf_metric'}).count(over=Args.get('ui.dashboard_window', '1h')).above(0, inclusive=False).count(by=['metric_name', 'forgecicd_ingest_source']).publish(label='A')
EOF

  sort_by                 = "+metric_name"
  disable_sampling        = true
  hide_missing_values     = true
  max_precision           = 0
  secondary_visualization = "Sparkline"
  time_range              = 3600
  unit_prefix             = "Metric"

  legend_options_fields {
    enabled  = true
    property = "metric_name"
  }
  legend_options_fields {
    enabled  = true
    property = "forgecicd_ingest_source"
  }

  viz_options {
    display_name = "Reporting MTS"
    label        = "A"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "metric_ingest" {
  name            = "Forge Metric API Ingestion Health"
  description     = "Start with Token ID and the problem overview. Compare archived routing context, direct drops, and MTS creation limits, then use the detailed charts for exact reasons. Use Ingest source only for the retained metric inventory. Invalid requires sender-response or collector-log evidence; timeout is an internal post-limit signal, not a network timeout."
  dashboard_group = var.dashboard_group
  time_range      = "-1h"

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  variable {
    property               = "tokenId"
    alias                  = "Token ID"
    description            = "Limit ingestion diagnostics to a Forge-owned Splunk Observability ingest token ID."
    values                 = []
    value_required         = false
    values_suggested       = local.token_ids
    restricted_suggestions = true
    replace_only           = true
  }

  variable {
    property               = "forgecicd_ingest_source"
    alias                  = "Ingest source"
    description            = "Limit the retained Forge metric inventory to a configured stable sender-source dimension."
    values                 = []
    value_required         = false
    values_suggested       = local.ingest_sources
    restricted_suggestions = true
    replace_only           = true
  }

  chart {
    chart_id = signalfx_time_chart.problem_overview.id
    row      = 0
    column   = 0
    width    = 12
    height   = 2
  }
  chart {
    chart_id = signalfx_time_chart.ingest_volume.id
    row      = 2
    column   = 0
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.datapoint_drops.id
    row      = 2
    column   = 6
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.mts_admission.id
    row      = 3
    column   = 0
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.metric_type_backfill.id
    row      = 3
    column   = 6
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.payload_bytes.id
    row      = 4
    column   = 0
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.metadata_rest.id
    row      = 4
    column   = 6
    width    = 6
    height   = 1
  }
  chart {
    chart_id = signalfx_time_chart.cloudwatch_metric_stream.id
    row      = 5
    column   = 0
    width    = 12
    height   = 1
  }
  chart {
    chart_id = signalfx_list_chart.usage_objects.id
    row      = 6
    column   = 0
    width    = 12
    height   = 2
  }
  chart {
    chart_id = signalfx_list_chart.retained_metrics_by_source.id
    row      = 8
    column   = 0
    width    = 12
    height   = 2
  }
}
