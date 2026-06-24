# Splunk Cloud Data Manager

This module configures Splunk Data Manager integrations for AWS log and metadata ingestion.

## Why This Module Exists

Forge sends EC2, Lambda, EKS, CloudWatch, and security metadata through supported Splunk Cloud ingestion paths. Managing Data Manager as code keeps observability reproducible instead of click-driven.

## What It Manages

- CloudFormation stacks for CloudWatch, custom CloudWatch, and security metadata integrations.
- Generated Splunk data input modules for each integration payload.
- A metadata Lambda trigger for EC2 tag enrichment.
- Outputs containing the resulting Splunk input JSON.

## Operational Notes

- This module expects valid Splunk Cloud credentials and Data Manager configuration.
- CloudFormation stack failures usually point to AWS-side permissions or region support.
- Custom log group selection determines which Forge logs arrive in Splunk Cloud.

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
