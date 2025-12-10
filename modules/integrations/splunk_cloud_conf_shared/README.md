<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |
| <a name="requirement_splunk"></a> [splunk](#requirement\_splunk) | >= 1.4.30 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |
| <a name="provider_splunk"></a> [splunk](#provider\_splunk) | 1.4.32 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [splunk_configs_conf.forgecicd_aws_billing_cur](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_billing_cur_instance_id](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_billing_cur_volume_id](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_extract_log_time_message](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_forgecicd](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_global_lambda_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_lambda_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_runner_ci_result](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_runner_gh_runner_version](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_runner_pages_github_repo_name](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_cloudwatchlogs_runner_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_extra_lambda_ec2_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_extra_lambda_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_dind](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_init_dind_externals](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_init_dind_rootless](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_init_docker_creds](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_init_work](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_listener](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_listener_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_log_hook](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_log_worker](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_manager](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_manager_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_runner](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_runner_ci_result](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_runner_gh_runner_version](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_kube_container_runner_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_metadata](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_metadata_image_id](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_metadata_instance_id](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_metadata_instance_type](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_metadata_tenant_fields](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_runner_arc](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_runner_ec2](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_runner_logs_json](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_runner_logs_logs](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_runner_logs_tenant_fields_event](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_runner_logs_tenant_fields_logs](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_configs_conf.forgecicd_trust_validation](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/configs_conf) | resource |
| [splunk_data_ui_views.ci_jobs](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/data_ui_views) | resource |
| [splunk_data_ui_views.ec2_scale_up_errors](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/data_ui_views) | resource |
| [splunk_data_ui_views.tenant](https://registry.terraform.io/providers/splunk/splunk/latest/docs/resources/data_ui_views) | resource |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile (i.e. generated via 'sl aws session generate') to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_splunk_conf"></a> [splunk\_conf](#input\_splunk\_conf) | n/a | <pre>object({<br/>    splunk_cloud = string<br/>    acl = object({<br/>      app     = string<br/>      owner   = string<br/>      sharing = string<br/>      read    = list(string)<br/>      write   = list(string)<br/>    })<br/>    index   = string<br/>    tenant_names = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
