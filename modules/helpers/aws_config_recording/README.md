# AWS Config Recording

This module enables continuous AWS Config recording for caller-selected AWS resource types and, by default, creates the regional delivery path for those records.

## What It Manages

- A configuration recorder for the resource types supplied through `recorded_resource_types`.
- An IAM role with the AWS managed Config recorder policy.
- A private, encrypted, versioned S3 bucket for AWS Config snapshots and history.
- An encrypted SQS queue and dead-letter queue for regional `.json.gz` Config object notifications.
- Least-privilege bucket and queue policies for AWS Config delivery and S3 notifications.
- A delivery channel targeting the managed bucket.
- An enabled recorder status.

## Operational Notes

- Deploy one instance of this module per AWS account and Region where configuration recording is required.
- The account and Region must not already have a customer-managed configuration recorder or delivery channel with conflicting names.
- The default IAM role name includes `aws_region`, preventing global IAM name collisions when the module is deployed in multiple Regions.
- The default bucket name is `<account-id>-forge-aws-config-<region>` and the default queue name is `<account-id>-forge-aws-config-events-<region>`.
- Notifications match keys under `AWSLogs/<account-id>/Config/<region>/` that end in `.json.gz`. This includes Config history and snapshot objects; S3 key filters cannot select the nested `ConfigHistory` segment alone.
- SQS messages contain S3 event metadata. Consumers retrieve the compressed object from S3 and should tolerate duplicate or out-of-order notifications. They must also detect and ignore the initial S3 `s3:TestEvent`, which has no Config object and uses a different payload shape.
- The main queue uses a five-minute visibility timeout for Splunk SQS-based S3 ingestion and moves a message to the encrypted dead-letter queue after five failed receives. Both queues retain messages for 14 days.
- To preserve an existing central delivery bucket, set `delivery_bucket_name`. In that compatibility mode this module creates no S3 bucket, SQS queue, or bucket notification, and the external bucket owner must manage delivery permissions and notifications.
- Removing an existing `delivery_bucket_name` switches future delivery to the new regional bucket; historical objects remain in the external bucket and are not copied by this module.
- Setting `delivery_bucket_name` after using managed mode plans removal of the managed bucket and queue. Because `force_destroy` is disabled, first retain or migrate the bucket in state, or explicitly remove every object version and delete marker before applying the ownership change.
- S3 notification configuration is atomic. Do not add a second Terraform owner for notifications on the managed bucket.

## Splunk Data Manager

This module is only the AWS-side producer. Its managed S3, SQS, and policy contract is compatible with a Splunk Data Manager custom S3 input, but the module does not configure Splunk or prove that AWS Config objects are parsed and indexed correctly.

When both modules are composed in one Terraform root, use the
`splunk_s3_logs` output directly with the Forge `splunk_cloud_data_manager`
module's `s3-custom-logs` input:

```hcl
s3_logs_config = {
  s3-custom-logs = [{
    enabled            = true
    name               = "forge-aws-config-prod"
    iam_region         = "eu-west-1"
    index              = "forge-prod-index"
    source_type        = "forgecicd:aws:config:s3"
    sqs_urls           = [module.aws_config_recording.splunk_s3_logs.sqs.url]
    s3_bucket_patterns = [module.aws_config_recording.splunk_s3_logs.bucket_arn]
    kms_key_arns       = []
  }]
}
```

The Forge Terragrunt helper and integration examples are independent deployment
roots. For those examples, apply the helper, run
`terragrunt output -json splunk_s3_logs`, and copy `sqs.url` and `bucket_arn`
into the disabled AWS Config item in the Data Manager `config.yml` before
enabling it.

- Keep the queue dedicated to one Data Manager input. Competing consumers can delete notifications before Splunk reads them.
- `kms_key_arns` is empty because the managed bucket uses SSE-S3 (`AES256`), not SSE-KMS.
- AWS Config files wrap records in a `configurationItems` array. Before enabling ingestion, deploy and validate the custom source type's Splunk parsing so each configuration item has the intended event boundary and timestamp. Merely naming the source type `forgecicd:aws:config:s3` does not select the Splunk AWS add-on's Config decoder through this custom-log path.
- Validate the complete path with a real AWS Config `.json.gz` object: confirm its S3 notification reaches the queue, Data Manager consumes it, and the expected individual events appear in the selected index. Queue activity alone is not end-to-end success.
- Notifications apply only to newly created objects. Existing objects require a separate historical-ingestion or controlled-copy procedure.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.59.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_config_configuration_recorder.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_iam_role.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_notification.config_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_ownership_controls.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_servicecatalogappregistry_application.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |
| [aws_sqs_queue.config_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.config_events_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.config_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.config_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.config_delivery_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.config_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_delivery_bucket_name"></a> [delivery\_bucket\_name](#input\_delivery\_bucket\_name) | Optional name of an existing S3 delivery bucket. When null, the module creates a regional bucket and SQS notification queue. | `string` | `null` | no |
| <a name="input_delivery_channel_name"></a> [delivery\_channel\_name](#input\_delivery\_channel\_name) | Name of the AWS Config delivery channel. | `string` | `"default"` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name of the IAM role used by AWS Config. Defaults to forge-aws-config-recorder-<aws\_region>. | `string` | `null` | no |
| <a name="input_recorded_resource_types"></a> [recorded\_resource\_types](#input\_recorded\_resource\_types) | AWS Config resource types to record, using identifiers such as AWS::EC2::Instance. | `set(string)` | n/a | yes |
| <a name="input_recorder_name"></a> [recorder\_name](#input\_recorder\_name) | Name of the AWS Config configuration recorder. | `string` | `"default"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of additional tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_configuration_recorder_name"></a> [configuration\_recorder\_name](#output\_configuration\_recorder\_name) | Name of the enabled AWS Config configuration recorder. |
| <a name="output_delivery_bucket_arn"></a> [delivery\_bucket\_arn](#output\_delivery\_bucket\_arn) | ARN of the S3 bucket receiving AWS Config snapshots and history. |
| <a name="output_delivery_bucket_name"></a> [delivery\_bucket\_name](#output\_delivery\_bucket\_name) | Name of the S3 bucket receiving AWS Config snapshots and history. |
| <a name="output_recorded_resource_types"></a> [recorded\_resource\_types](#output\_recorded\_resource\_types) | AWS resource types recorded by AWS Config. |
| <a name="output_splunk_s3_logs"></a> [splunk\_s3\_logs](#output\_splunk\_s3\_logs) | Managed AWS Config S3 and SQS resources for a Splunk Data Manager s3-custom-logs input, or null when an external bucket is used. |
| <a name="output_sqs"></a> [sqs](#output\_sqs) | SQS queue receiving managed AWS Config S3 object notifications, or null when an external bucket is used. |
<!-- END_TF_DOCS -->
