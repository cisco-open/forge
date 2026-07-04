# ARC Deployment Wrapper

This module maps tenant runner configuration into the platform ARC module.

## Why This Module Exists

Forge tenant configuration is written once, then expanded into platform modules. This wrapper is the tenant-facing ARC adapter: it translates runner specs, labels, images, resource limits, ECR access, and cluster migration flags into the lower-level Kubernetes resources.

## What It Manages

- A call into `modules/platform/arc` for the tenant.
- ARC controller settings derived from the tenant prefix and namespace.
- Scale set definitions for each configured Kubernetes runner pool.
- Runner IAM policy attachments and ECR registry wiring.

## Operational Notes

- This is the module to inspect when a tenant config value does not appear in the generated ARC resources.
- The wrapper does not create the EKS cluster; it targets an existing cluster by name.
- A tenant with no ARC runner specs will not create ARC scale sets.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_arc"></a> [arc](#module\_arc) | ../arc | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_runner_configs"></a> [runner\_configs](#input\_runner\_configs) | n/a | <pre>object({<br/>    prefix           = string<br/>    arc_cluster_name = string<br/>    ghes_url         = string<br/>    ghes_org         = string<br/>    github_app = object({<br/>      key_base64      = string<br/>      id              = string<br/>      installation_id = string<br/>    })<br/>    migrate_arc_cluster                 = optional(bool, false)<br/>    runner_iam_role_managed_policy_arns = list(string)<br/>    runner_group_name                   = string<br/>    log_level                           = optional(string, "INFO")<br/>    runner_specs = map(object({<br/>      runner_size = object({<br/>        max_runners = number<br/>        min_runners = number<br/>      })<br/>      scale_set_name   = string<br/>      scale_set_type   = string<br/>      scale_set_labels = list(string)<br/>      container_images = optional(object({<br/>        actions_runner = optional(string, "ghcr.io/actions/actions-runner:latest")<br/>        busybox        = optional(string, "public.ecr.aws/docker/library/busybox:stable")<br/>        dind_rootless  = optional(string, "public.ecr.aws/docker/library/docker:dind-rootless")<br/>      }), {})<br/>      container_limits_cpu         = string<br/>      container_limits_memory      = string<br/>      volume_requests_storage_size = string<br/>      volume_requests_storage_type = string<br/>      container_requests_cpu       = string<br/>      container_requests_memory    = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_tenant_configs"></a> [tenant\_configs](#input\_tenant\_configs) | n/a | <pre>object({<br/>    ecr_registries = list(string)<br/>    tags           = map(string)<br/>    name           = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arc_cluster_name"></a> [arc\_cluster\_name](#output\_arc\_cluster\_name) | Name of the Kubernetes cluster used for ARC runners. |
| <a name="output_arc_runners_arn_map"></a> [arc\_runners\_arn\_map](#output\_arc\_runners\_arn\_map) | Map of ARC runner keys to their IAM role ARNs. |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | Map of ARC runner subnet IDs to their CIDR blocks. |
<!-- END_TF_DOCS -->
