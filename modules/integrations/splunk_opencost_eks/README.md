# Splunk OpenCost for EKS

This module installs OpenCost and an OpenCost-ready Prometheus release on an EKS cluster.

OpenCost exposes Prometheus-format cost metrics on `/metrics`. The existing `splunk_otel_eks` module should scrape those metrics through the static pod and service annotations configured here.

## What It Manages

- `helm_release.managed_prometheus`
- `helm_release.opencost`
- EKS cluster data lookups for Helm authentication

## Fixed Defaults

- OpenCost namespace: `opencost`
- OpenCost service account: `opencost`
- OpenCost chart: `opencost/opencost` version `2.5.25`
- Prometheus namespace: `prometheus-system`
- Prometheus chart: `prometheus-community/prometheus` version `29.17.0`
- Prometheus keeps kube-state-metrics and node-exporter enabled for OpenCost source metrics
- Prometheus scrapes the OpenCost exporter with the upstream OpenCost scrape config
- OpenCost metrics endpoint: `http://opencost.opencost.svc.cluster.local:9003/metrics`

## Example

```hcl
module "splunk_opencost_eks" {
  source = "../../../modules/integrations/splunk_opencost_eks"

  aws_profile = "forge-prod"
  aws_region  = "eu-west-1"
  cluster_name = "forge-euw1-prod"

  default_tags = {
    ApplicationName = "forge"
    ResourceOwner   = "forge"
  }
}
```

Enable Prometheus autodiscovery in `splunk_otel_eks` so the Splunk collector scrapes the OpenCost annotations.
