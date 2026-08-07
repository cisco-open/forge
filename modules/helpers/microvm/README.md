# Lambda MicroVM Regional Foundation

This regional helper creates the AWS resources and IAM boundaries needed to
build and operate Forge GitHub runner images on AWS Lambda MicroVMs, including
the VPC egress connectors used by those runners.

## Why This Module Exists

Lambda requires the ZIP used to create or update a MicroVM image to be in an S3
bucket in the same region as the image. Image builds use a dedicated
Lambda-trusted IAM role. This module makes those regional publishing
prerequisites repeatable without taking ownership of the runner runtime.

The AWS provider does not currently expose a Lambda MicroVM image resource.
This module therefore reserves an image-name prefix solely as an IAM namespace.
The internal runner-image repository owns all image names, every
`CreateMicrovmImage` and `UpdateMicrovmImage` call, the `loggingConfig` supplied
to those calls, and the actual image lifecycle.

The provider also does not currently expose a native Lambda Network Connector
resource. The module manages the official `AWS::Lambda::NetworkConnector`
CloudFormation resource through `aws_cloudformation_stack`; no `awscc` provider
is needed.

## What It Manages

- One encrypted, versioned, non-public regional S3 artifact bucket with
  lifecycle cleanup under `lambda-microvms/`.
- A Lambda-trusted build role for artifact access, optional private ECR pulls,
  and scoped build-log writes.
- For every `network_connectors` map entry, a dedicated no-ingress security
  group with IPv4 or dual-stack egress and a regional Network Connector for
  `MicroVm` compute. Entries can target different VPCs in the same region.
- One regional Lambda-trusted ENI operator role shared by every connector, with
  the AWS-managed `AWSLambdaNetworkConnectorOperatorPolicy` attached.
- One unattached, reusable managed policy for operating only the reserved
  MicroVM image namespace and passing its Network Connectors. A consumer module
  attaches it to its own control-plane role.
- One AppRegistry application following the Forge helper-module convention.

## Regional Deployment

Deploy the module once in each supported region. The S3 bucket and all Lambda
MicroVM APIs are regional. IAM roles and policies are account-global, so their
names include the region to avoid collisions between deployments.

```hcl
module "microvm" {
  source = "../../modules/helpers/microvm"

  aws_profile  = "forge-prod"
  aws_region   = "eu-west-1"
  default_tags = local.default_tags
  tags         = local.tags

  artifact_bucket_name    = "123456789012-forge-microvm-artifacts-eu-west-1"
  artifact_retention_days = 30
  image_name_prefix       = "srea-gh-runner-ubuntu-arm64"

  ecr_repository_arns = [
    "arn:aws:ecr:eu-west-1:123456789012:repository/actions-runner-base-image",
  ]

  network_connectors = {
    cicd = {
      name       = "srea-gh-runner-egress"
      vpc_id     = "vpc-0123456789abcdef0"
      subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
    }
    private = {
      name             = "srea-gh-runner-private"
      vpc_id           = "vpc-0aaaaaaaaaaaaaaaa"
      subnet_ids       = ["subnet-0aaaaaaaaaaaaaaaa"]
      network_protocol = "DualStack"
    }
  }
}
```

Map keys such as `cicd` and `private` are stable Terraform identities for all
per-connector resources. Every subnet is read during planning and must belong
to the `vpc_id` in the same map entry. Each connector gets its own security
group rather than reusing an EKS or application security group. Its
`0.0.0.0/0` egress rule permits outbound IPv4 at the security-group layer;
actual reachability remains bounded by that VPC's subnet route tables and
NACLs. `DualStack` additionally permits IPv6 egress.

An image create/update request can bake in zero or one egress connector. A
MicroVM run can attach up to ten runtime connectors. This foundation may create
the regional connector inventory, but the internal image publisher selects any
baked connector and `terraform-aws-github-runner` selects the runtime connector
set for each launch.

## Image and Logging Ownership

Forge owns only this regional foundation: S3 storage, IAM boundaries, one
AppRegistry application, and the configured Network Connectors. It does not
create or update MicroVM images and does not manage a CloudWatch log group.
`forge_subscription` owns the single account-level publisher policy attached to
`role_for_forge_runners`; this regional helper does not create or attach a
publisher policy.

The internal runner-image publisher currently selects
`/aws/lambda/microvms/<image-name>` in its `loggingConfig`. The build role has
resource-scoped permissions for AWS to create and write groups matching
`/aws/lambda/microvms/<image_name_prefix>-*`, but the groups are not Terraform
resources here. If the publisher switches to a disabled logging configuration,
those permissions are simply unused.

## IAM Boundaries

The runtime policy is scoped to the `<image_name_prefix>-*` namespace owned by
the internal publisher. This module does not enumerate images or define runner
sizes. The account-level publisher policy in `forge_subscription` independently
scopes resource-aware image operations to the configured regional namespaces.

The prefix can contain at most 62 characters, leaving room for the namespace
separator and at least one suffix character within AWS's 64-character image
name limit. The publisher remains responsible for validating each complete
image name.

`forge_subscription` creates one publisher policy for
`role_for_forge_runners`, aggregating the configured regional artifact buckets,
build roles, image namespaces, and ECR repositories. Its `iam:PassRole`
permission is restricted to the regional image-build roles and
`iam:PassedToService = lambda.amazonaws.com`. Keeping that policy at the
subscription level avoids creating one account-global IAM policy per region.

This helper deliberately does not create runtime execution or control-plane
roles. The runner module owns those roles and their service permissions because
it knows the runtime trust boundary. That consumer is also responsible for
granting `iam:PassRole` to its execution role and can attach `usage_policy_arn`
for the image-scoped Lambda MicroVM actions and Network Connector permissions.

Lambda assumes one regional operator role for all connectors. That role trusts
`lambda.amazonaws.com` for `sts:AssumeRole` only, matching the role generated by
AWS SAM, and has the AWS-managed `AWSLambdaNetworkConnectorOperatorPolicy`
attached. Despite the per-region role name and connector configuration, that
managed policy uses `ec2:*:*` resource patterns and is not region-, subnet-, or
security-group-scoped in IAM. Connector configuration selects the network
targets but is not an IAM boundary. Every connector sharing the role also
shares its failure and blast radius, and AWS may update the managed policy.

Creating or updating a connector passes the operator role to Lambda. The
identity running Terraform or Terragrunt must therefore have `iam:PassRole` on
`forge-microvm-network-operator-<region>`, restricted with
`iam:PassedToService = lambda.amazonaws.com`. This module does not grant
permissions to its deployment caller.

AWS exposes `lambda:PassNetworkConnector` without resource-level IAM scoping,
so the usage policy isolates that action and `ListNetworkConnectors` in a
wildcard statement while scoping `GetNetworkConnector` to the configured
connector ARNs.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudformation_stack.connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_iam_policy.build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.operator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.operator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_servicecatalogappregistry_application.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |
| [aws_vpc_security_group_egress_rule.ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ipv6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.artifact_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_assume_operator_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_service_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_artifact_bucket_name"></a> [artifact\_bucket\_name](#input\_artifact\_bucket\_name) | Optional name for the regional MicroVM build-artifact bucket. The default includes the account ID and region. | `string` | `null` | no |
| <a name="input_artifact_retention_days"></a> [artifact\_retention\_days](#input\_artifact\_retention\_days) | Number of days to retain current and noncurrent MicroVM build artifacts. | `number` | `30` | no |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region in which to create the Lambda MicroVM prerequisites. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of default tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_ecr_repository_arns"></a> [ecr\_repository\_arns](#input\_ecr\_repository\_arns) | Optional regional ECR repository ARNs from which MicroVM image builds can pull runner base images. | `set(string)` | `[]` | no |
| <a name="input_image_name_prefix"></a> [image\_name\_prefix](#input\_image\_name\_prefix) | IAM namespace prefix reserved for externally published Lambda MicroVM image names. This module does not create or enumerate images. | `string` | n/a | yes |
| <a name="input_network_connectors"></a> [network\_connectors](#input\_network\_connectors) | Regional Lambda MicroVM Network Connectors keyed by a stable consumer-defined identity. | <pre>map(object({<br/>    name             = string<br/>    vpc_id           = string<br/>    subnet_ids       = set(string)<br/>    network_protocol = optional(string, "IPv4")<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of module-specific tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_appregistry_application_arn"></a> [appregistry\_application\_arn](#output\_appregistry\_application\_arn) | ARN of the AppRegistry application representing this regional helper deployment. |
| <a name="output_artifact_bucket_arn"></a> [artifact\_bucket\_arn](#output\_artifact\_bucket\_arn) | ARN of the regional S3 bucket used for Lambda MicroVM build artifacts. |
| <a name="output_artifact_bucket_name"></a> [artifact\_bucket\_name](#output\_artifact\_bucket\_name) | Name of the regional S3 bucket used for Lambda MicroVM build artifacts. |
| <a name="output_artifact_prefix"></a> [artifact\_prefix](#output\_artifact\_prefix) | Bucket prefix to which the MicroVM image publisher uploads content-addressed build artifacts. |
| <a name="output_build_role_arn"></a> [build\_role\_arn](#output\_build\_role\_arn) | ARN of the Lambda-trusted role used during MicroVM image builds. |
| <a name="output_connector_arns"></a> [connector\_arns](#output\_connector\_arns) | Map of connector key to ARN returned by each AWS::Lambda::NetworkConnector CloudFormation resource. |
| <a name="output_security_group_ids"></a> [security\_group\_ids](#output\_security\_group\_ids) | Map of connector key to its dedicated no-ingress security group ID. |
| <a name="output_usage_policy_arn"></a> [usage\_policy\_arn](#output\_usage\_policy\_arn) | ARN of the reusable regional policy for operating MicroVM images in the reserved namespace and passing their Network Connectors. |
<!-- END_TF_DOCS -->
