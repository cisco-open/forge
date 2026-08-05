mock_provider "kubernetes" {}

variables {
  namespace = "forge-tenant"
}

run "teleport_tenant_rbac_contract" {
  command = plan

  assert {
    condition = (
      kubernetes_cluster_role_v1.impersonate.metadata[0].name == "teleport-forge-tenant-impersonate"
      && kubernetes_cluster_role_v1.impersonate.rule[0].resources[0] == "users"
      && contains(kubernetes_cluster_role_v1.impersonate.rule[0].resources, "groups")
      && contains(kubernetes_cluster_role_v1.impersonate.rule[0].resources, "serviceaccounts")
      && kubernetes_cluster_role_v1.impersonate.rule[0].verbs[0] == "impersonate"
    )
    error_message = "Teleport tenant RBAC must allow impersonation of users, groups, and service accounts for the tenant namespace."
  }

  assert {
    condition = (
      kubernetes_cluster_role_v1.pods.metadata[0].name == "teleport-forge-tenant-pods"
      && contains(kubernetes_cluster_role_v1.pods.rule[0].resources, "pods")
      && contains(kubernetes_cluster_role_v1.pods.rule[0].resources, "pods/log")
      && contains(kubernetes_cluster_role_v1.pods.rule[0].resources, "pods/exec")
      && contains(kubernetes_cluster_role_v1.pods.rule[0].verbs, "get")
      && contains(kubernetes_cluster_role_v1.pods.rule[0].verbs, "watch")
      && contains(kubernetes_cluster_role_v1.pods.rule[0].verbs, "list")
    )
    error_message = "Teleport tenant RBAC must preserve pod, log, and exec read access."
  }

  assert {
    condition = (
      kubernetes_cluster_role_binding_v1.impersonate.metadata[0].name == "teleport-forge-tenant-impersonate-binding"
      && kubernetes_cluster_role_binding_v1.impersonate.subject[0].name == "teleport-forge-tenant"
      && kubernetes_role_binding_v1.pods.metadata[0].namespace == "forge-tenant"
      && kubernetes_role_binding_v1.pods.role_ref[0].name == "teleport-forge-tenant-pods"
      && kubernetes_role_binding_v1.pods.subject[0].name == "teleport-forge-tenant"
    )
    error_message = "Teleport tenant RBAC bindings must stay scoped to the generated tenant group and namespace."
  }
}
