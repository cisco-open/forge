mock_provider "aws" {
  mock_data "aws_eks_cluster" {
    defaults = {
      endpoint = "https://eks.example.com"
      certificate_authority = [{
        data = "dGVzdA=="
      }]
      identity = [{
        oidc = [{
          issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
        }]
      }]
    }
  }

  mock_data "aws_eks_cluster_auth" {
    defaults = {
      token = "mock-token"
    }
  }

  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    }
  }

  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-token"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/splunk-otel-forge-euw1-dev-ec2-describe-role"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/splunk-otel-forge-euw1-dev-ec2-describe-policy"
    }
  }
}

mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "time" {}

variables {
  aws_profile  = "test"
  aws_region   = "us-east-1"
  cluster_name = "forge-euw1-dev"
  splunk_otel_collector = {
    splunk_platform_endpoint        = "https://splunk.example.com/services/collector"
    splunk_platform_index           = "forge-prod-index"
    gateway                         = true
    environment                     = "prod"
    discovery                       = true
    splunk_observability_realm      = "us1"
    splunk_observability_ingest_url = "https://ingest.us1.signalfx.com"
    splunk_observability_api_url    = "https://api.us1.signalfx.com"
    splunk_observability_profiling  = false
  }
  prometheus_autodiscovery_enabled = true
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

run "splunk_otel_eks_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.splunk_otel_ec2_describe.name == "splunk-otel-forge-euw1-dev-ec2-describe-role"
      && aws_iam_policy.ec2_describe_instances.name == "splunk-otel-forge-euw1-dev-ec2-describe-policy"
      && aws_iam_role_policy_attachment.splunk_otel_ec2_describe.role == aws_iam_role.splunk_otel_ec2_describe.name
      && aws_iam_role.splunk_otel_ec2_describe.tags.Product == "Forge"
      && aws_iam_role.splunk_otel_ec2_describe.tags.Env == "test"
    )
    error_message = "Splunk OTel EKS must keep the EC2 describe IAM role, policy, attachment, and merged tags."
  }

  assert {
    condition = (
      aws_eks_pod_identity_association.eks_pod_identity.cluster_name == "forge-euw1-dev"
      && aws_eks_pod_identity_association.eks_pod_identity.namespace == "splunk-otel-collector"
      && aws_eks_pod_identity_association.eks_pod_identity.service_account == "splunk-otel-collector"
      && aws_eks_pod_identity_association.eks_pod_identity.role_arn == aws_iam_role.splunk_otel_ec2_describe.arn
      && time_sleep.wait_for_pod_identity_propagation.create_duration == "180s"
      && time_sleep.wait_for_pod_identity_propagation.destroy_duration == "30s"
    )
    error_message = "Splunk OTel EKS must bind the collector service account through EKS Pod Identity and keep the propagation delay."
  }

  assert {
    condition = (
      helm_release.splunk_otel_collector.name == "splunk-otel-collector"
      && helm_release.splunk_otel_collector.chart == "splunk-otel-collector"
      && helm_release.splunk_otel_collector.namespace == "splunk-otel-collector"
      && helm_release.splunk_otel_collector.create_namespace == true
      && contains([for item in helm_release.splunk_otel_collector.set : "${item.name}=${item.value}"], "clusterName=forge-euw1-dev")
      && contains([for item in helm_release.splunk_otel_collector.set : "${item.name}=${item.value}"], "splunkPlatform.index=forge-prod-index")
      && contains([for item in helm_release.splunk_otel_collector.set : "${item.name}=${item.value}"], "autodetect.prometheus=true")
    )
    error_message = "Splunk OTel Helm release must keep chart identity and configured cluster, platform index, and Prometheus autodiscovery values."
  }
}
