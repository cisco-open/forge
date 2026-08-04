# Forge Metric API Ingestion Health dashboard

This module creates the `Forge Metric API Ingestion Health` dashboard for
diagnosing metric API ingestion by Forge-owned Splunk Observability ingest
token ID. Eight token-scoped panels use an explicit, realm-validated inventory
of 61 `ByToken` organization metrics. Some of these internal or newer metrics
are not present in the public organization-metrics catalog but compile in the
target realm. A separate source-scoped inventory uses a restricted source
allow-list with a wildcard metric query.

The dashboard separates the evidence into nine panels:

1. API calls and received datapoints
2. payload bytes
3. direct datapoint drops by reason
4. metric time-series creation and admission limits
5. metric type and backfill traffic
6. metadata and REST throttling
7. CloudWatch Metric Stream ingestion
8. current usage and object gauges
9. retained metric names and reporting MTS by ingest source

`token_ids` is a static allow-list and is also exposed as the restricted
`Token ID` dashboard selector. Token IDs identify senders but are not token
secrets. When the list is empty, every token-scoped chart uses a sentinel
filter so the dashboard does not show organization-wide token data.
Select one `Token ID` when investigating a sender so multi-plot charts and the
usage table remain readable.

`ingest_sources` is a separate allow-list for stable
`forgecicd_ingest_source` dimension values. Its restricted `Ingest source`
selector applies only to the metric-name inventory. The chart counts distinct
retained MTS that reported at least once in the dashboard window, grouped by
exact metric name and source. An empty allow-list fails closed. List charts
display up to 100 rows at a time, so select one `Ingest source` when the
inventory is larger.

The source inventory is not a token-to-metric lookup. It only includes senders
that emit `forgecicd_ingest_source`, cannot include metrics rejected before
retention, and remains subject to SignalFlow MTS limits. Adding the dimension
creates new MTS identities, so validate MTS admission before rolling it out to
an existing high-cardinality sender.

## Interpreting drop signals

- `Invalid` is an admission result, not a complete root cause. Correlate its
  time window with the sender response, collector logs, and an exact metric
  time-series query.
- `Timeout` is Splunk's internal post-limit signal: datapoints were not
  attempted after recent account limiting. It is not a client network timeout,
  and a token-level timeout does not prove that token caused the
  organization-wide limit.
- A successful sender or collector transport counter does not prove the metric
  time series was retained. Check direct drops and MTS admission panels before
  querying the exact metric time series.

## Adopting an existing dashboard

Applying this module without state adoption creates another dashboard and
charts. If the dashboard was first created manually, import the dashboard and
every matching existing chart into the correct downstream Terraform state
before the first apply. For the original eight-panel dashboard, import those
eight charts and let Terraform create the new source-inventory chart. If that
chart was also created manually, import it as well. Keep live object IDs in the
deployment/import procedure, not in this reusable module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.33.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_dashboard.metric_ingest](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard) | resource |
| [signalfx_list_chart.retained_metrics_by_source](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_list_chart.usage_objects](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/list_chart) | resource |
| [signalfx_time_chart.cloudwatch_metric_stream](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.datapoint_drops](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.ingest_volume](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.metadata_rest](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.metric_type_backfill](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.mts_admission](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [signalfx_time_chart.payload_bytes](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/time_chart) | resource |
| [terraform_data.dashboard_parent](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dashboard_group"></a> [dashboard\_group](#input\_dashboard\_group) | Splunk Observability dashboard group ID. | `string` | n/a | yes |
| <a name="input_ingest_sources"></a> [ingest\_sources](#input\_ingest\_sources) | Stable forgecicd\_ingest\_source dimension values emitted by Forge metric senders. An empty list makes the retained-metric inventory chart fail closed. | `list(string)` | `[]` | no |
| <a name="input_token_ids"></a> [token\_ids](#input\_token\_ids) | Splunk Observability ingest token IDs owned by Forge. These are identifiers, not token secrets. An empty list makes every token-scoped chart fail closed. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
