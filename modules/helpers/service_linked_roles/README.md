# Service-Linked Roles

This module creates the EC2 Spot service-linked role that Forge expects to exist in runner accounts.

## Why This Module Exists

EC2 runner pools can use Spot capacity, which depends on an account-level service-linked role. Creating that role up front avoids first-use failures during runner scale-up.

## What It Manages

- The EC2 Spot service-linked role.
- Standard account and region inputs for bootstrap consistency.

## Operational Notes

- Apply this before enabling Spot-backed EC2 runner pools.
- The EC2 Spot service-linked role is account scoped and may already exist; Terraform should own it only where this module is the bootstrap authority.
- This does not decide whether a runner pool uses Spot; that is configured in the EC2 deployment specs.

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
| [aws_iam_service_linked_role.spot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_servicecatalogappregistry_application.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/servicecatalogappregistry_application) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
