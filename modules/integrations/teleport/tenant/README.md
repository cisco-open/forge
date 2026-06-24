# Teleport Tenant RBAC

This module creates the Kubernetes RBAC objects that let Teleport users inspect a specific tenant namespace.

## Why This Module Exists

Tenant-scoped live debugging should not imply cluster-wide access. This module grants the impersonation and pod permissions needed for a tenant namespace while preserving the namespace boundary.

## What It Manages

- ClusterRole and ClusterRoleBinding for impersonation.
- Namespace RoleBinding for pod access.
- Bindings scoped by the tenant namespace input.

## Operational Notes

- Use this only with the parent Teleport module and the organization access process.
- Keep namespace names aligned with Forge tenant names.
- Expand permissions deliberately; this is an audited human-access path.

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
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_cluster_role_binding_v1.impersonate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.impersonate](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.pods](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_role_binding_v1.pods](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for chart installation | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
