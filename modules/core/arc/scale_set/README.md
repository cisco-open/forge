<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.27 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.36.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_pod_identity_association.eks_pod_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.runner_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.runner_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.gha_runner_scale_set](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map.hook_extension](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.hook_pre_post_job](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_role.k8s](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role) | resource |
| [kubernetes_role_binding.k8s](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_service_account_v1.runner_sa](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | Chart URL for the Helm chart | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Chart version for the Helm chart | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster. | `string` | n/a | yes |
| <a name="input_container_actions_runner"></a> [container\_actions\_runner](#input\_container\_actions\_runner) | Container Actions Runner | `string` | n/a | yes |
| <a name="input_container_ecr_registries"></a> [container\_ecr\_registries](#input\_container\_ecr\_registries) | List of ECR registries. | `list(string)` | n/a | yes |
| <a name="input_container_limits_cpu"></a> [container\_limits\_cpu](#input\_container\_limits\_cpu) | Container CPU limits. | `string` | n/a | yes |
| <a name="input_container_limits_memory"></a> [container\_limits\_memory](#input\_container\_limits\_memory) | Container memory limits. | `string` | n/a | yes |
| <a name="input_container_requests_cpu"></a> [container\_requests\_cpu](#input\_container\_requests\_cpu) | Container CPU requests. | `string` | n/a | yes |
| <a name="input_container_requests_memory"></a> [container\_requests\_memory](#input\_container\_requests\_memory) | Container memory requests. | `string` | n/a | yes |
| <a name="input_controller"></a> [controller](#input\_controller) | controller = {<br/>      namespace: "Namespace for the controller."<br/>      service\_account: "Service Account Name of the controller."<br/>    } | <pre>object({<br/>    namespace       = string<br/>    service_account = string<br/>  })</pre> | n/a | yes |
| <a name="input_ghes_org"></a> [ghes\_org](#input\_ghes\_org) | GitHub organization. | `string` | n/a | yes |
| <a name="input_ghes_url"></a> [ghes\_url](#input\_ghes\_url) | GitHub Enterprise Server URL. | `string` | n/a | yes |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | The name of the Iam Role | `string` | n/a | yes |
| <a name="input_migrate_arc_cluster"></a> [migrate\_arc\_cluster](#input\_migrate\_arc\_cluster) | Flag to indicate if the cluster is being migrated. | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for chart installation | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | OIDC provider ARN for the EKS cluster. | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release | `string` | n/a | yes |
| <a name="input_runner_group_name"></a> [runner\_group\_name](#input\_runner\_group\_name) | Name of the group applied to all runners. | `string` | n/a | yes |
| <a name="input_runner_iam_role_managed_policy_arns"></a> [runner\_iam\_role\_managed\_policy\_arns](#input\_runner\_iam\_role\_managed\_policy\_arns) | Attach AWS or customer-managed IAM policies (by ARN) to the runner IAM role | `list(string)` | n/a | yes |
| <a name="input_runner_size"></a> [runner\_size](#input\_runner\_size) | runner\_size = {<br/>      max\_runners: "Maximum number of runners."<br/>      min\_runners: "Minimum number of runners."<br/>    } | <pre>object({<br/>    max_runners = number<br/>    min_runners = number<br/>  })</pre> | n/a | yes |
| <a name="input_scale_set_name"></a> [scale\_set\_name](#input\_scale\_set\_name) | Name of the scale set. | `string` | n/a | yes |
| <a name="input_scale_set_type"></a> [scale\_set\_type](#input\_scale\_set\_type) | Type of the scale set(k8s or dind). | `string` | n/a | yes |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | Name of the Secret. | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Name of the Service Account. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_volume_requests_storage_size"></a> [volume\_requests\_storage\_size](#input\_volume\_requests\_storage\_size) | Volume storage requests. | `string` | n/a | yes |
| <a name="input_volume_requests_storage_type"></a> [volume\_requests\_storage\_type](#input\_volume\_requests\_storage\_type) | Volume storage requests. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_runner_role_arn"></a> [runner\_role\_arn](#output\_runner\_role\_arn) | n/a |
<!-- END_TF_DOCS -->
