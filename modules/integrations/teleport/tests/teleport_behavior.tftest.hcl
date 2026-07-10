mock_provider "aws" {
  mock_data "aws_eks_cluster" {
    defaults = {
      endpoint = "https://eks.example.com"
      certificate_authority = [{
        data = "dGVzdA=="
      }]
    }
  }

  mock_data "aws_eks_cluster_auth" {
    defaults = {
      token = "mock-token"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/forge-euw1-dev-teleport"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/forge-euw1-dev-eks-policy"
    }
  }
}

mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  aws_profile = "test"
  aws_region  = "us-east-1"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
  tenants = ["tenant-a", "tenant-b"]
  teleport_config = {
    cluster_name                = "forge-euw1-dev"
    teleport_iam_role_to_assume = "arn:aws:iam::999999999999:role/teleport"
  }
}

run "teleport_parent_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.teleport_role.name == "forge-euw1-dev-teleport"
      && aws_iam_role.teleport_role.tags.Product == "Forge"
      && aws_iam_role.teleport_role.tags.Env == "test"
      && aws_iam_policy.eks_policy.name == "forge-euw1-dev-eks-policy"
      && aws_iam_role_policy_attachment.attach_eks_policy.role == aws_iam_role.teleport_role.name
      && aws_iam_role_policy_attachment.attach_eks_policy.policy_arn == aws_iam_policy.eks_policy.arn
    )
    error_message = "Teleport integration must keep the cluster-scoped IAM role, EKS policy, attachment, and merged tags."
  }

  assert {
    condition = (
      kubernetes_config_map_v1.aws_auth_teleport[0].metadata[0].name == "aws-auth"
      && kubernetes_config_map_v1.aws_auth_teleport[0].metadata[0].namespace == "kube-system"
      && strcontains(kubernetes_config_map_v1.aws_auth_teleport[0].data.mapRoles, "teleport-tenant-a")
      && strcontains(kubernetes_config_map_v1.aws_auth_teleport[0].data.mapRoles, "teleport-tenant-b")
      && strcontains(kubernetes_config_map_v1.aws_auth_teleport[0].data.mapRoles, aws_iam_role.teleport_role.arn)
    )
    error_message = "Teleport integration must render aws-auth mapRoles for every tenant group against the Teleport IAM role."
  }

  assert {
    condition = (
      output.teleport_role_arn == aws_iam_role.teleport_role.arn
      && output.teleport_cluster_name == "forge-euw1-dev"
      && output.teleport_account_id == "123456789012"
      && output.teleport_tenant_groups["tenant-a"] == "teleport-tenant-a"
      && output.teleport_tenant_groups["tenant-b"] == "teleport-tenant-b"
    )
    error_message = "Teleport outputs must expose role ARN, cluster/account identity, and tenant group mapping."
  }
}
