run "metric_ingest_dashboard_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_dashboard\" \"metric_ingest\"",
      "resource \"signalfx_time_chart\" \"problem_overview\"",
      "resource \"signalfx_time_chart\" \"ingest_volume\"",
      "resource \"signalfx_time_chart\" \"payload_bytes\"",
      "resource \"signalfx_time_chart\" \"datapoint_drops\"",
      "resource \"signalfx_time_chart\" \"mts_admission\"",
      "resource \"signalfx_time_chart\" \"metric_type_backfill\"",
      "resource \"signalfx_time_chart\" \"metadata_rest\"",
      "resource \"signalfx_time_chart\" \"cloudwatch_metric_stream\"",
      "resource \"signalfx_list_chart\" \"usage_objects\"",
      "resource \"terraform_data\" \"dashboard_parent\"",
      "Forge Metric API Ingestion Health",
      "Metric ingest problems and archived volume by token",
      "Archived datapoints (context)",
      "Direct datapoint drops",
      "MTS creation limit calls",
      "CloudWatch Metric Stream drops",
      "not a deduplicated loss total",
      "filter('tokenId', '$${join(\"', '\", local.token_ids)}')",
      "__forge_metric_ingest_scope_not_configured__",
      "property               = \"tokenId\"",
      "restricted_suggestions = true",
      "replace_only           = true",
      "property = \"sf_originatingMetric\"",
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
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Metric-ingest dashboard source inventory is incomplete: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 85
    error_message = "Metric-ingest dashboard source inventory count must remain pinned."
  }
}
