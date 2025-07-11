<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.90 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.36.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_splunk_otel_eks_blue"></a> [splunk\_otel\_eks\_blue](#module\_splunk\_otel\_eks\_blue) | ../splunk_otel_eks | n/a |
| <a name="module_splunk_otel_eks_green"></a> [splunk\_otel\_eks\_green](#module\_splunk\_otel\_eks\_green) | ../splunk_otel_eks | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_eks_cluster_names"></a> [eks\_cluster\_names](#input\_eks\_cluster\_names) | The name of the EKS clusters | <pre>object({<br/>    blue  = string<br/>    green = string<br/>  })</pre> | n/a | yes |
| <a name="input_splunk_otel_collector"></a> [splunk\_otel\_collector](#input\_splunk\_otel\_collector) | Configuration for the Splunk OpenTelemetry Collector | <pre>object({<br/>    splunk_observability_realm     = string<br/>    splunk_platform_endpoint       = string<br/>    splunk_platform_index          = string<br/>    gateway                        = bool<br/>    splunk_observability_profiling = bool<br/>    environment                    = string<br/>    discovery                      = bool<br/>  })</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
