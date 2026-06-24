# ARC Scale Set Controller

This module installs the GitHub Actions Runner Controller scale set controller for a tenant namespace.

## Why This Module Exists

The controller is the Kubernetes-side reconciler that watches GitHub demand and manages runner scale sets. Forge installs it as code so each tenant namespace has a predictable controller, GitHub App secret, and logging posture.

## What It Manages

- The tenant namespace.
- The GitHub App Kubernetes secret used by ARC.
- The `gha-runner-scale-set-controller` Helm release.

## Operational Notes

- Controller version should move deliberately with ARC chart upgrades.
- During ARC cluster migration, `migrate_arc_cluster` removes the in-cluster controller resources while leaving external tenant identity intact.
- Controller logs are the first place to inspect when GitHub sees demand but runner pods are not being created.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.gha_runner_scale_set_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.controller_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.github_app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_name"></a> [chart\_name](#input\_chart\_name) | Chart URL for the Helm chart | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Chart version for the Helm chart | `string` | n/a | yes |
| <a name="input_controller_config"></a> [controller\_config](#input\_controller\_config) | n/a | <pre>object({<br/>    name = string<br/>  })</pre> | n/a | yes |
| <a name="input_github_app"></a> [github\_app](#input\_github\_app) | GitHub App configuration | <pre>object({<br/>    key_base64      = string<br/>    id              = string<br/>    installation_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for the ARC controller (one of: debug, info, warn, error). Case-insensitive. | `string` | `"INFO"` | no |
| <a name="input_migrate_arc_cluster"></a> [migrate\_arc\_cluster](#input\_migrate\_arc\_cluster) | Flag to indicate if the cluster is being migrated. | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for chart installation | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
