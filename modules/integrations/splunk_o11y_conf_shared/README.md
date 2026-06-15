<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.47 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.30.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_dashboard_billing"></a> [dashboard\_billing](#module\_dashboard\_billing) | ./dashboards/billing | n/a |
| <a name="module_dashboard_dynamodb"></a> [dashboard\_dynamodb](#module\_dashboard\_dynamodb) | ./dashboards/dynamodb | n/a |
| <a name="module_dashboard_ebs"></a> [dashboard\_ebs](#module\_dashboard\_ebs) | ./dashboards/ebs | n/a |
| <a name="module_dashboard_forge_impact"></a> [dashboard\_forge\_impact](#module\_dashboard\_forge\_impact) | ./dashboards/forge_impact | n/a |
| <a name="module_dashboard_lambda"></a> [dashboard\_lambda](#module\_dashboard\_lambda) | ./dashboards/lambda | n/a |
| <a name="module_dashboard_runner_ec2"></a> [dashboard\_runner\_ec2](#module\_dashboard\_runner\_ec2) | ./dashboards/runner_ec2 | n/a |
| <a name="module_dashboard_runner_k8s"></a> [dashboard\_runner\_k8s](#module\_dashboard\_runner\_k8s) | ./dashboards/runner_k8s | n/a |
| <a name="module_dashboard_sqs"></a> [dashboard\_sqs](#module\_dashboard\_sqs) | ./dashboards/sqs | n/a |
| <a name="module_detector_k8s"></a> [detector\_k8s](#module\_detector\_k8s) | ./detectors/k8s | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [signalfx_dashboard_group.forgecicd](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard_group) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_dashboard_variables"></a> [dashboard\_variables](#input\_dashboard\_variables) | Variables for Dashboards | <pre>object({<br/>    runner_k8s = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    runner_ec2 = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    billing = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    sqs = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    ebs = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    lambda = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    dynamodb = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_detector_name_prefix"></a> [detector\_name\_prefix](#input\_detector\_name\_prefix) | Prefix to use for Splunk Observability detector names. | `string` | `"ForgeCICD"` | no |
| <a name="input_detector_notifications"></a> [detector\_notifications](#input\_detector\_notifications) | Detector notification destinations. When null, detectors notify the configured Splunk Observability team. Set to [] to create detectors without notifications. | `list(string)` | `null` | no |
| <a name="input_k8s_detector_config"></a> [k8s\_detector\_config](#input\_k8s\_detector\_config) | Thresholds and durations for Forge Kubernetes detectors. | <pre>object({<br/>    container_restarts_duration  = string<br/>    container_restarts_threshold = number<br/>    failed_pods_duration         = string<br/>    failed_pods_threshold        = number<br/>    otel_no_data_duration        = string<br/>    otel_no_data_fill_duration   = string<br/>    pending_pods_duration        = string<br/>    pending_pods_threshold       = number<br/>    platform_pods_duration       = string<br/>    platform_unhealthy_threshold = number<br/>  })</pre> | <pre>{<br/>  "container_restarts_duration": "10m",<br/>  "container_restarts_threshold": 0,<br/>  "failed_pods_duration": "5m",<br/>  "failed_pods_threshold": 0,<br/>  "otel_no_data_duration": "10m",<br/>  "otel_no_data_fill_duration": "4h",<br/>  "pending_pods_duration": "10m",<br/>  "pending_pods_threshold": 0,<br/>  "platform_pods_duration": "5m",<br/>  "platform_unhealthy_threshold": 0<br/>}</pre> | no |
| <a name="input_k8s_otel_collector_config"></a> [k8s\_otel\_collector\_config](#input\_k8s\_otel\_collector\_config) | Configuration for Splunk OpenTelemetry Collector health detectors. | <pre>object({<br/>    min_running_pods       = number<br/>    namespace              = string<br/>    no_running_duration    = string<br/>    pod_issue_duration     = string<br/>    pod_name_filter        = string<br/>    restart_duration       = string<br/>    restart_threshold      = number<br/>    stale_metrics_duration = string<br/>  })</pre> | <pre>{<br/>  "min_running_pods": 1,<br/>  "namespace": "splunk-otel-collector",<br/>  "no_running_duration": "10m",<br/>  "pod_issue_duration": "5m",<br/>  "pod_name_filter": "splunk-otel-collector*",<br/>  "restart_duration": "10m",<br/>  "restart_threshold": 0,<br/>  "stale_metrics_duration": "4h"<br/>}</pre> | no |
| <a name="input_k8s_platform_namespaces"></a> [k8s\_platform\_namespaces](#input\_k8s\_platform\_namespaces) | Namespaces that contain platform pods required for runner scheduling and networking. | `list(string)` | <pre>[<br/>  "kube-system",<br/>  "karpenter",<br/>  "calico-system",<br/>  "tigera-operator"<br/>]</pre> | no |
| <a name="input_splunk_api_url"></a> [splunk\_api\_url](#input\_splunk\_api\_url) | URL for plunk Observability Cloud API. | `string` | n/a | yes |
| <a name="input_splunk_organization_id"></a> [splunk\_organization\_id](#input\_splunk\_organization\_id) | organization ID for Splunk Observability Cloud. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team ID | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
