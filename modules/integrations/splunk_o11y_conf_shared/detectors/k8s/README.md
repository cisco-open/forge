<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | < 10.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_detector.k8s_otel_collector_health](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.k8s_otel_no_data](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.k8s_other_namespace_pods_unhealthy](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.k8s_platform_pods_unhealthy](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.k8s_tenant_container_restarts](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.k8s_tenant_pods_failed](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |
| [signalfx_detector.k8s_tenant_pods_pending](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/detector) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | n/a | yes |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. | `list(string)` | n/a | yes |
| <a name="input_dynamic_variables"></a> [dynamic\_variables](#input\_dynamic\_variables) | Additional dynamic variable definitions used to derive detector scope. | <pre>list(object({<br/>    property               = string<br/>    alias                  = string<br/>    description            = string<br/>    values                 = list(string)<br/>    value_required         = bool<br/>    values_suggested       = list(string)<br/>    restricted_suggestions = bool<br/>  }))</pre> | `[]` | no |
| <a name="input_k8s_detector_config"></a> [k8s\_detector\_config](#input\_k8s\_detector\_config) | Thresholds and durations for Forge Kubernetes detectors. | <pre>object({<br/>    container_restarts_duration  = string<br/>    container_restarts_threshold = number<br/>    failed_pods_duration         = string<br/>    failed_pods_threshold        = number<br/>    otel_no_data_duration        = string<br/>    otel_no_data_fill_duration   = string<br/>    pending_pods_duration        = string<br/>    pending_pods_threshold       = number<br/>    platform_pods_duration       = string<br/>    platform_unhealthy_threshold = number<br/>  })</pre> | n/a | yes |
| <a name="input_k8s_otel_collector_config"></a> [k8s\_otel\_collector\_config](#input\_k8s\_otel\_collector\_config) | Configuration for Splunk OpenTelemetry Collector health detectors. | <pre>object({<br/>    min_running_pods       = number<br/>    namespace              = string<br/>    no_running_duration    = string<br/>    pod_issue_duration     = string<br/>    pod_name_filter        = string<br/>    restart_duration       = string<br/>    restart_threshold      = number<br/>    stale_metrics_duration = string<br/>  })</pre> | n/a | yes |
| <a name="input_k8s_platform_namespaces"></a> [k8s\_platform\_namespaces](#input\_k8s\_platform\_namespaces) | Namespaces that contain platform pods required for runner scheduling and networking. | `list(string)` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team ID. | `string` | n/a | yes |
| <a name="input_tenant_names"></a> [tenant\_names](#input\_tenant\_names) | List of Forge tenant namespaces. | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
