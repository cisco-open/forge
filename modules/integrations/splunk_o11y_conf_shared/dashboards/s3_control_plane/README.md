# Forge Control Plane - S3

Terraform-managed Splunk Observability dashboard for Forge S3 buckets without
the `TenantName` tag.

It adapts the built-in AWS S3 storage panels to the metrics observed in the
Forge operations account. Request, transfer, latency, and error panels are
intentionally omitted until those S3 request metrics are available.
