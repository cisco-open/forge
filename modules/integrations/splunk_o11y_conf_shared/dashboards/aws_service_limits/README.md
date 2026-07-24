# Forge Control Plane - AWS Service Limits

Terraform-managed Splunk Observability dashboard for AWS Trusted Advisor
`ServiceLimitUsage` metrics observed in the Forge operations account.

The dashboard adapts the built-in AWS service-limit overview into one chart per
supported AWS service used by Forge:

- EC2;
- EBS;
- VPC;
- Auto Scaling;
- DynamoDB;
- IAM;
- CloudFormation;
- Route 53.

Each chart reports the one-day average limit usage percentage by Trusted Advisor
region and service limit. Services without `ServiceLimitUsage` telemetry are not
represented.
