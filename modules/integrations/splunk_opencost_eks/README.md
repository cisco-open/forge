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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.managed_prometheus](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.opencost](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | `null` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The EKS cluster name and OpenCost default cluster ID. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_metrics_endpoint"></a> [metrics\_endpoint](#output\_metrics\_endpoint) | n/a |
| <a name="output_metrics_host"></a> [metrics\_host](#output\_metrics\_host) | n/a |
| <a name="output_metrics_path"></a> [metrics\_path](#output\_metrics\_path) | n/a |
| <a name="output_metrics_port"></a> [metrics\_port](#output\_metrics\_port) | n/a |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | n/a |
| <a name="output_prometheus_endpoint"></a> [prometheus\_endpoint](#output\_prometheus\_endpoint) | n/a |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | n/a |
| <a name="output_service_account_name"></a> [service\_account\_name](#output\_service\_account\_name) | n/a |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | n/a |
<!-- END_TF_DOCS -->
