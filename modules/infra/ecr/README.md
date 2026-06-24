# ECR Repositories

This module creates and manages ECR repositories used by Forge operational images.

## Why This Module Exists

Forge uses images for runners, sidecars, Lambdas, and integration helpers. Central ECR repositories keep those artifacts under platform control and make lifecycle cleanup repeatable.

## What It Manages

- One or more ECR repositories from the `repositories` input.
- Lifecycle policies for repository cleanup.
- Repository names exported for downstream modules or pipelines.

## Operational Notes

- Repository names are part of the contract with image-build and runner configuration.
- Lifecycle rules should match the release and rollback window used by the platform.
- Cross-account pull access is handled elsewhere; this module creates the repositories themselves.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ecr_lifecycle_policy.ops_cleanup_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.ops_container_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_repositories"></a> [repositories](#input\_repositories) | A list of ECR repositories to create. Mutability must be 'MUTABLE' or 'IMMUTABLE'. | <pre>list(object({<br/>    repo         = string<br/>    mutability   = string<br/>    scan_on_push = bool<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ops_container_repository_names"></a> [ops\_container\_repository\_names](#output\_ops\_container\_repository\_names) | n/a |
<!-- END_TF_DOCS -->
