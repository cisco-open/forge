mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/forge-runner-scale-set"
    }
  }
}

mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  chart_name    = "gha-runner-scale-set"
  chart_version = "0.12.1"
  container_images = {
    actions_runner = "ghcr.io/actions/actions-runner:2.328.0"
    busybox        = "busybox:1.36"
    dind_rootless  = "docker:dind-rootless"
  }
  controller = {
    namespace       = "arc-system"
    service_account = "arc-controller"
  }
  iam_role_name                       = "forge-runner-scale-set"
  namespace                           = "tenant-a"
  release_name                        = "tenant-a-linux"
  ghes_org                            = "cisco-open"
  ghes_url                            = ""
  runner_group_name                   = "forge-runners"
  runner_iam_role_managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  tags = {
    Product = "Forge"
    Env     = "test"
  }
  runner_size = {
    max_runners = 10
    min_runners = 1
  }
  scale_set_name               = "tenant-a-linux"
  scale_set_type               = "k8s"
  scale_set_labels             = ["self-hosted", "linux", "forge"]
  service_account              = "runner"
  secret_name                  = "github-app"
  container_limits_cpu         = "2"
  container_limits_memory      = "4Gi"
  container_requests_cpu       = "1"
  container_requests_memory    = "2Gi"
  volume_requests_storage_size = "20Gi"
  volume_requests_storage_type = "gp3"
  cluster_name                 = "forge-euw1-dev"
  container_ecr_registries     = ["123456789012.dkr.ecr.us-east-1.amazonaws.com"]
  oidc_provider_arn            = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  migrate_arc_cluster          = false
  log_level                    = "DEBUG"
}

run "scale_set_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.runner_role.name == "forge-runner-scale-set"
      && aws_iam_role.runner_role.tags.Product == "Forge"
      && aws_iam_role.runner_role.tags.Env == "test"
      && aws_iam_role_policy_attachment.runner_role_policy_attachment[0].role == aws_iam_role.runner_role.name
      && aws_iam_role_policy_attachment.runner_role_policy_attachment[0].policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
      && output.runner_role_arn == aws_iam_role.runner_role.arn
    )
    error_message = "ARC scale set must keep runner IAM role, managed policy attachment, tags, and role ARN output."
  }

  assert {
    condition = (
      kubernetes_config_map_v1.hook_extension[0].metadata[0].name == "hook-extension-tenant-a-linux"
      && kubernetes_config_map_v1.hook_extension[0].metadata[0].namespace == "tenant-a"
      && strcontains(kubernetes_config_map_v1.hook_extension[0].data["container-podspec.yaml"], "serviceAccountName: \"runner\"")
      && kubernetes_service_account_v1.runner_sa[0].metadata[0].name == "runner"
      && kubernetes_service_account_v1.runner_sa[0].metadata[0].namespace == "tenant-a"
    )
    error_message = "ARC scale set must keep hook extension and runner service account scoped to the tenant namespace."
  }

  assert {
    condition = (
      helm_release.gha_runner_scale_set[0].name == "tenant-a-linux"
      && helm_release.gha_runner_scale_set[0].namespace == "tenant-a"
      && helm_release.gha_runner_scale_set[0].chart == "gha-runner-scale-set"
      && helm_release.gha_runner_scale_set[0].version == "0.12.1"
      && helm_release.gha_runner_scale_set[0].timeout == 1200
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "tenant-a-linux")
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "forge-runners")
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "https://github.com/cisco-open")
    )
    error_message = "ARC scale set Helm release must render runner set name, runner group, and GitHub config URL from inputs."
  }

  assert {
    condition = (
      aws_eks_pod_identity_association.eks_pod_identity[0].cluster_name == "forge-euw1-dev"
      && aws_eks_pod_identity_association.eks_pod_identity[0].namespace == "tenant-a"
      && aws_eks_pod_identity_association.eks_pod_identity[0].service_account == "runner"
      && aws_eks_pod_identity_association.eks_pod_identity[0].role_arn == aws_iam_role.runner_role.arn
    )
    error_message = "ARC scale set must bind runner service account to the runner IAM role through EKS Pod Identity."
  }
}

run "scale_set_dind_contract" {
  command = plan

  variables {
    scale_set_type = "dind"
    scale_set_name = "tenant-a-dind"
    release_name   = "tenant-a-dind"
    ghes_url       = "https://github.example.cisco.com"
    log_level      = "INFO"
  }

  assert {
    condition = (
      length(kubernetes_role_v1.k8s) == 0
      && length(kubernetes_role_binding_v1.k8s) == 0
      && length(kubernetes_service_account_v1.runner_sa) == 1
      && length(aws_eks_pod_identity_association.eks_pod_identity) == 1
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "https://github.example.cisco.com/cisco-open")
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "tenant-a-dind")
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "docker:dind-rootless")
      && strcontains(helm_release.gha_runner_scale_set[0].values[0], "pod-identity-token-custom")
    )
    error_message = "DinD scale sets must skip tenant k8s RBAC, keep service account and Pod Identity wiring, and render GHES/DinD Helm values."
  }
}

run "scale_set_migration_contract" {
  command = plan

  variables {
    migrate_arc_cluster = true
    scale_set_type      = "dind"
  }

  assert {
    condition = (
      aws_iam_role.runner_role.name == "forge-runner-scale-set"
      && output.runner_role_arn == aws_iam_role.runner_role.arn
      && length(kubernetes_config_map_v1.hook_extension) == 0
      && length(kubernetes_config_map_v1.hook_pre_post_job) == 0
      && length(kubernetes_service_account_v1.runner_sa) == 0
      && length(kubernetes_role_v1.k8s) == 0
      && length(kubernetes_role_binding_v1.k8s) == 0
      && length(helm_release.gha_runner_scale_set) == 0
      && length(aws_eks_pod_identity_association.eks_pod_identity) == 0
    )
    error_message = "ARC scale set migration mode must retain the IAM role output while suppressing Helm, Kubernetes, Pod Identity, and DinD OIDC resources."
  }
}
