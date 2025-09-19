<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.27 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.36.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.14.0 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.5 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_controller"></a> [controller](#module\_controller) | ./scale_set_controller | n/a |
| <a name="module_scale_sets"></a> [scale\_sets](#module\_scale\_sets) | ./scale_set | n/a |

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.storage_class](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [null_resource.apply_ec2_node_class](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.apply_node_pool](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_openid_connect_provider.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_subnet.eks_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [external_external.karpenter_ec2nodeclass](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.update_kubeconfig](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e. generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_controller_config"></a> [controller\_config](#input\_controller\_config) | controller\_config = {<br/>      release\_name: "Name of the Helm release."<br/>      namespace: "Namespace for chart installation."<br/>      chart\_name: "Chart name for the Helm chart."<br/>      chart\_version: "Chart version for the Helm chart."<br/>      name: "Name of the controller."<br/>    } | <pre>object({<br/>    release_name  = string<br/>    namespace     = string<br/>    chart_name    = string<br/>    chart_version = string<br/>    name          = string<br/>  })</pre> | n/a | yes |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_ghes_org"></a> [ghes\_org](#input\_ghes\_org) | GitHub organization. | `string` | n/a | yes |
| <a name="input_ghes_url"></a> [ghes\_url](#input\_ghes\_url) | GitHub Enterprise Server URL. | `string` | n/a | yes |
| <a name="input_github_app"></a> [github\_app](#input\_github\_app) | GitHub App configuration | <pre>object({<br/>    key_base64      = string<br/>    id              = string<br/>    installation_id = string<br/>  })</pre> | n/a | yes |
| <a name="input_migrate_arc_cluster"></a> [migrate\_arc\_cluster](#input\_migrate\_arc\_cluster) | Flag to indicate if the cluster should be migrated. | `bool` | `false` | no |
| <a name="input_multi_runner_config"></a> [multi\_runner\_config](#input\_multi\_runner\_config) | multi\_runner\_config = {<br/>      runner\_config: {<br/>        runner\_size: {<br/>          max\_runners: "Maximum number of runners."<br/>          min\_runners: "Minimum number of runners."<br/>        }<br/>        controller = {<br/>          service\_account: "Service Account Name of the controller."<br/>          namespace: "Namespace for the controller."<br/>        }<br/>        prefix: "Prefix for naming resources."<br/>        scale\_set\_name: "Name of the scale set."<br/>        runner\_iam\_role\_managed\_policy\_arns: "Attach AWS or customer-managed IAM policies (by ARN) to the runner IAM role."<br/>      }<br/>      runner\_set\_configs: {<br/>        release\_name: "Name of the Helm release."<br/>        namespace: "Namespace for chart installation."<br/>        chart\_name: "Chart name for the Helm chart."<br/>        chart\_version: "Chart version for the Helm chart."<br/>      }<br/>    } | <pre>map(object({<br/>    runner_set_configs = object({<br/>      release_name  = string<br/>      namespace     = string<br/>      chart_name    = string<br/>      chart_version = string<br/>    })<br/>    runner_config = object({<br/>      runner_size = object({<br/>        max_runners = number<br/>        min_runners = number<br/>      })<br/>      prefix                              = string<br/>      scale_set_name                      = string<br/>      scale_set_type                      = string<br/>      container_limits_cpu                = string<br/>      container_limits_memory             = string<br/>      container_requests_cpu              = string<br/>      container_requests_memory           = string<br/>      volume_requests_storage_size        = string<br/>      volume_requests_storage_type        = string<br/>      container_actions_runner            = string<br/>      container_ecr_registries            = list(string)<br/>      runner_iam_role_managed_policy_arns = list(string)<br/>      controller = object({<br/>        service_account = string<br/>        namespace       = string<br/>      })<br/>    })<br/>  }))</pre> | n/a | yes |
| <a name="input_runner_group_name"></a> [runner\_group\_name](#input\_runner\_group\_name) | Name of the group applied to all runners. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_runners_map"></a> [runners\_map](#output\_runners\_map) | n/a |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | n/a |
<!-- END_TF_DOCS -->
