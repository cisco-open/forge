# Forge Tenant - S3

Terraform-managed Splunk Observability dashboard for tenant-tagged Forge S3 buckets.

The dashboard adapts the built-in AWS S3 storage panels to the metrics currently
present in the Forge operations account:

- active bucket count;
- largest buckets;
- object count;
- storage by class.

S3 storage metrics are published daily, so the dashboard uses a two-day default
window. Request, transfer, latency, and error panels are intentionally omitted
until S3 request metrics are enabled and observed for Forge buckets.
