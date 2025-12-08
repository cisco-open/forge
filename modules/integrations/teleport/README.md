<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.36.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tenant"></a> [tenant](#module\_tenant) | ./tenant | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.eks_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.teleport_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_eks_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [kubernetes_config_map_v1.aws_auth_teleport](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.eks_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e. generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_teleport_config"></a> [teleport\_config](#input\_teleport\_config) | Map of IAM roles to assume for teleport access, including EKS cluster ARNs and other roles. | <pre>object({<br/>    cluster_name                = string<br/>    teleport_iam_role_to_assume = string<br/>  })</pre> | n/a | yes |
| <a name="input_tenants"></a> [tenants](#input\_tenants) | List of tenants to create roles for. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_teleport_account_id"></a> [teleport\_account\_id](#output\_teleport\_account\_id) | AWS account ID where Teleport role and resources are created. |
| <a name="output_teleport_cluster_name"></a> [teleport\_cluster\_name](#output\_teleport\_cluster\_name) | EKS cluster name used by the Teleport integration. |
| <a name="output_teleport_role_arn"></a> [teleport\_role\_arn](#output\_teleport\_role\_arn) | ARN of the IAM role created for Teleport access to the EKS cluster. |
| <a name="output_teleport_tenant_groups"></a> [teleport\_tenant\_groups](#output\_teleport\_tenant\_groups) | Map of tenant name to Kubernetes group name used in aws-auth (teleport-<tenant>). |
<!-- END_TF_DOCS -->
