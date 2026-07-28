# Forge Runner Logs Ingestion dashboard

This module creates a pipeline-specific Splunk Observability dashboard for the
Forge runner-log path from SQS through Lambda and Kinesis Data Streams to
Amazon Data Firehose and Splunk HEC.

The charts use exact resource-name filters and retain the shared AWS account,
region, and product-family dashboard variables.
