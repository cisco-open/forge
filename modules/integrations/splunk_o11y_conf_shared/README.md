<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |
| <a name="requirement_signalfx"></a> [signalfx](#requirement\_signalfx) | < 10.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |
| <a name="provider_signalfx"></a> [signalfx](#provider\_signalfx) | 9.23.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dashboard_billing"></a> [dashboard\_billing](#module\_dashboard\_billing) | ./dashboards/billing | n/a |
| <a name="module_dashboard_dynamodb"></a> [dashboard\_dynamodb](#module\_dashboard\_dynamodb) | ./dashboards/dynamodb | n/a |
| <a name="module_dashboard_ebs"></a> [dashboard\_ebs](#module\_dashboard\_ebs) | ./dashboards/ebs | n/a |
| <a name="module_dashboard_lambda"></a> [dashboard\_lambda](#module\_dashboard\_lambda) | ./dashboards/lambda | n/a |
| <a name="module_dashboard_runner_ec2"></a> [dashboard\_runner\_ec2](#module\_dashboard\_runner\_ec2) | ./dashboards/runner_ec2 | n/a |
| <a name="module_dashboard_runner_k8s"></a> [dashboard\_runner\_k8s](#module\_dashboard\_runner\_k8s) | ./dashboards/runner_k8s | n/a |
| <a name="module_dashboard_sqs"></a> [dashboard\_sqs](#module\_dashboard\_sqs) | ./dashboards/sqs | n/a |

## Resources

| Name | Type |
|------|------|
| [signalfx_dashboard_group.forgecicd](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs/resources/dashboard_group) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e., generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_dashboard_variables"></a> [dashboard\_variables](#input\_dashboard\_variables) | Variables for Dashboards | <pre>object({<br/>    runner_k8s = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    runner_ec2 = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    billing = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    sqs = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    ebs = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    lambda = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>    dynamodb = object({<br/>      tenant_names = list(string)<br/>      dynamic_variables = list(object({<br/>        property               = string<br/>        alias                  = string<br/>        description            = string<br/>        values                 = list(string)<br/>        value_required         = bool<br/>        values_suggested       = list(string)<br/>        restricted_suggestions = bool<br/>        }<br/>      ))<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_splunk_api_url"></a> [splunk\_api\_url](#input\_splunk\_api\_url) | URL for plunk Observability Cloud API. | `string` | n/a | yes |
| <a name="input_splunk_organization_id"></a> [splunk\_organization\_id](#input\_splunk\_organization\_id) | organization ID for Splunk Observability Cloud. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team ID | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
