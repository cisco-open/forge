mock_provider "aws" {
  mock_data "aws_eks_cluster" {
    defaults = {
      id       = "forge-euw1-dev"
      endpoint = "https://eks.example.test"
      certificate_authority = [
        {
          data = "Y2x1c3Rlci1jYQ=="
        }
      ]
      identity = [
        {
          oidc = [
            {
              issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
            }
          ]
        }
      ]
      vpc_config = [
        {
          cluster_security_group_id = "sg-cluster"
          control_plane_egress_mode = "DEFAULT"
          endpoint_private_access   = true
          endpoint_public_access    = false
          public_access_cidrs       = []
          security_group_ids        = ["sg-node"]
          subnet_ids                = ["subnet-a", "subnet-b"]
          vpc_id                    = "vpc-123456"
        }
      ]
    }
  }

  mock_data "aws_eks_cluster_auth" {
    defaults = {
      token = "cluster-token"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      cidr_block = "10.0.1.0/24"
    }
  }

  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/tenant-a-arc-runner-role"
    }
  }
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        updated = "true"
        data    = "{\"apiVersion\":\"karpenter.k8s.aws/v1\",\"kind\":\"EC2NodeClass\",\"metadata\":{\"name\":\"karpenter-arc-system\"},\"spec\":{\"tags\":{\"Product\":\"Forge\"}}}"
      }
    }
  }
}

mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "null" {}

variables {
  aws_profile       = "test"
  aws_region        = "us-east-1"
  eks_cluster_name  = "forge-euw1-dev"
  ghes_org          = "cisco-open"
  ghes_url          = ""
  runner_group_name = "forge-runners"
  github_app = {
    key_base64      = base64encode("private-key")
    id              = "12345"
    installation_id = "67890"
  }
  controller_config = {
    release_name  = "arc-controller"
    namespace     = "arc-system"
    chart_name    = "gha-runner-scale-set-controller"
    chart_version = "0.12.1"
    name          = "arc-controller"
  }
  multi_runner_config = {
    tenant_a = {
      runner_set_configs = {
        release_name  = "tenant-a-linux"
        namespace     = "tenant-a"
        chart_name    = "gha-runner-scale-set"
        chart_version = "0.12.1"
      }
      runner_config = {
        runner_size = {
          max_runners = 10
          min_runners = 1
        }
        prefix                       = "tenant-a"
        scale_set_name               = "tenant-a-linux"
        scale_set_type               = "k8s"
        scale_set_labels             = ["self-hosted", "linux", "forge"]
        container_limits_cpu         = "2"
        container_limits_memory      = "4Gi"
        container_requests_cpu       = "1"
        container_requests_memory    = "2Gi"
        volume_requests_storage_size = "20Gi"
        volume_requests_storage_type = "gp3"
        container_ecr_registries     = ["123456789012.dkr.ecr.us-east-1.amazonaws.com"]
        runner_iam_role_managed_policy_arns = [
          "arn:aws:iam::aws:policy/ReadOnlyAccess"
        ]
        controller = {
          service_account = "arc-controller"
          namespace       = "arc-system"
        }
      }
    }
  }
  tags = {
    Env     = "test"
    Product = "Forge"
  }
  migrate_arc_cluster = false
  log_level           = "DEBUG"
}

run "arc_single_runner_contract" {
  command = plan

  assert {
    condition = (
      output.runners_map.tenant_a.runner_role_arn == "arn:aws:iam::123456789012:role/tenant-a-arc-runner-role"
      && output.subnet_cidr_blocks["subnet-a"] == "10.0.1.0/24"
      && output.subnet_cidr_blocks["subnet-b"] == "10.0.1.0/24"
    )
    error_message = "ARC root module must expose runner role outputs and EKS subnet CIDR data for configured runner sets."
  }

  assert {
    condition = (
      strcontains(kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.metadata.name, "tenant-a-gp3-")
      && kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.parameters.type == "gp3"
      && kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.parameters.fsType == "ext4"
      && kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.parameters.encrypted == "true"
      && kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.reclaimPolicy == "Delete"
      && kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.volumeBindingMode == "WaitForFirstConsumer"
    )
    error_message = "ARC root module must render tenant storage classes from runner volume inputs."
  }

  assert {
    condition = (
      null_resource.apply_ec2_node_class.triggers.migrate_arc_cluster == "false"
      && null_resource.apply_node_pool.triggers.migrate_arc_cluster == "false"
      && length(null_resource.apply_node_pool.triggers.manifest_hash) == 64
    )
    error_message = "ARC root module must record non-migration Karpenter trigger values."
  }
}

run "arc_migration_contract" {
  command = plan

  variables {
    migrate_arc_cluster = true
  }

  assert {
    condition = (
      output.runners_map.tenant_a.runner_role_arn == "arn:aws:iam::123456789012:role/tenant-a-arc-runner-role"
      && null_resource.apply_ec2_node_class.triggers.migrate_arc_cluster == "true"
      && null_resource.apply_node_pool.triggers.migrate_arc_cluster == "true"
      && kubernetes_manifest.storage_class["tenant-a-gp3"].manifest.parameters.type == "gp3"
    )
    error_message = "ARC migration mode must keep runner outputs and storage classes while flipping Karpenter migration triggers."
  }
}

run "arc_empty_runner_config_contract" {
  command = plan

  variables {
    multi_runner_config = {}
  }

  assert {
    condition = (
      length(output.runners_map) == 0
      && length(output.subnet_cidr_blocks) == 0
      && length(kubernetes_manifest.storage_class) == 0
    )
    error_message = "ARC root module must suppress controller, scale-set, storage-class, and subnet outputs when no runners are configured."
  }
}
