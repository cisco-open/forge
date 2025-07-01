<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_arc"></a> [arc](#module\_arc) | ../../core/arc | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e. generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_runner_configs"></a> [runner\_configs](#input\_runner\_configs) | n/a | <pre>object({<br/>    prefix           = string<br/>    arc_cluster_name = string<br/>    ghes_url         = string<br/>    ghes_org         = string<br/>    github_app = object({<br/>      key_base64      = string<br/>      id              = string<br/>      installation_id = string<br/>    })<br/>    migrate_arc_cluster                 = optional(bool, false)<br/>    runner_iam_role_managed_policy_arns = list(string)<br/>    runner_group_name                   = string<br/>    runner_specs = map(object({<br/>      runner_size = object({<br/>        max_runners = number<br/>        min_runners = number<br/>      })<br/>      scale_set_name               = string<br/>      scale_set_type               = string<br/>      container_actions_runner     = string<br/>      container_limits_cpu         = string<br/>      container_limits_memory      = string<br/>      volume_requests_storage_size = string<br/>      volume_requests_storage_type = string<br/>      container_requests_cpu       = string<br/>      container_requests_memory    = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_tenant_configs"></a> [tenant\_configs](#input\_tenant\_configs) | n/a | <pre>object({<br/>    ecr_registries = list(string)<br/>    tags           = map(string)<br/>    name           = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arc_runners_arn_map"></a> [arc\_runners\_arn\_map](#output\_arc\_runners\_arn\_map) | n/a |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | n/a |
<!-- END_TF_DOCS -->
