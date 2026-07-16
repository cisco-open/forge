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
}

mock_provider "helm" {}

variables {
  aws_profile  = "test"
  aws_region   = "us-east-1"
  cluster_name = "forge-euw1-dev"
  default_tags = {
    Product = "Forge"
  }
}

run "opencost_helm_release_contract" {
  command = plan

  assert {
    condition = (
      helm_release.managed_prometheus.name == "prometheus"
      && helm_release.managed_prometheus.repository == "https://prometheus-community.github.io/helm-charts"
      && helm_release.managed_prometheus.chart == "prometheus"
      && helm_release.managed_prometheus.version == "29.17.0"
      && helm_release.managed_prometheus.namespace == "prometheus-system"
      && helm_release.managed_prometheus.create_namespace == true
      && helm_release.managed_prometheus.atomic == true
      && helm_release.managed_prometheus.timeout == 1200
    )
    error_message = "OpenCost integration must keep the managed Prometheus release, version, namespace, and safety flags."
  }

  assert {
    condition = (
      helm_release.opencost.name == "opencost"
      && helm_release.opencost.repository == "https://opencost.github.io/opencost-helm-chart"
      && helm_release.opencost.chart == "opencost"
      && helm_release.opencost.version == "2.5.26"
      && helm_release.opencost.namespace == "opencost"
      && helm_release.opencost.create_namespace == true
      && helm_release.opencost.atomic == true
      && helm_release.opencost.timeout == 1200
    )
    error_message = "OpenCost integration must keep the OpenCost release, version, namespace, and safety flags."
  }

  assert {
    condition = (
      contains([for item in helm_release.opencost.set : "${item.name}=${item.value}"], "opencost.exporter.defaultClusterId=forge-euw1-dev")
      && contains([for item in helm_release.opencost.set : "${item.name}=${item.value}"], "opencost.exporter.apiPort=9003")
      && contains([for item in helm_release.opencost.set : "${item.name}=${item.value}"], "opencost.prometheus.internal.namespaceName=prometheus-system")
      && contains([for item in helm_release.opencost.set : "${item.name}=${item.value}"], "opencost.prometheus.internal.serviceName=prometheus-server")
      && contains([for item in helm_release.opencost.set : "${item.name}=${item.value}"], "opencost.ui.enabled=false")
    )
    error_message = "OpenCost Helm values must keep the cluster ID, exporter port, internal Prometheus target, and disabled UI."
  }

  assert {
    condition = (
      output.namespace == "opencost"
      && output.release_name == "opencost"
      && output.metrics_endpoint == "http://opencost.opencost.svc.cluster.local:9003/metrics"
      && output.prometheus_endpoint == "http://prometheus-server.prometheus-system.svc.cluster.local:80"
    )
    error_message = "OpenCost outputs must continue exposing the service and Prometheus endpoints used by downstream telemetry wiring."
  }
}
