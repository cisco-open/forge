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
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.37.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.gha_runner_scale_set_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.controller_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.github_app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | Chart URL for the Helm chart | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Chart version for the Helm chart | `string` | n/a | yes |
| <a name="input_controller_config"></a> [controller\_config](#input\_controller\_config) | n/a | <pre>object({<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_github_app"></a> [github\_app](#input\_github\_app) | GitHub App configuration | <pre>object({<br/>    key_base64      = string<br/>    id              = string<br/>    installation_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_migrate_arc_cluster"></a> [migrate\_arc\_cluster](#input\_migrate\_arc\_cluster) | Flag to indicate if the cluster is being migrated. | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for chart installation | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
