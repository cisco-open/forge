<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.27 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.10.0 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_runners"></a> [runners](#module\_runners) | git::https://github.com/github-aws-runners/terraform-aws-github-runner.git//modules/multi-runner | 4b33b88a323f1a47bb250c9b31168e2289b0b15d |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.ec2_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_kms_alias.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.gh_runner_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.gh_runner_lambda_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ami.runner_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.ec2_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameter.ami_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnet.runner_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [external_external.download_lambdas](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Assuming single region for now. | `string` | n/a | yes |
| <a name="input_network_configs"></a> [network\_configs](#input\_network\_configs) | n/a | <pre>object({<br/>    vpc_id            = string<br/>    subnet_ids        = list(string)<br/>    lambda_subnet_ids = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_runner_configs"></a> [runner\_configs](#input\_runner\_configs) | n/a | <pre>object({<br/>    prefix                    = string<br/>    ghes_url                  = string<br/>    ghes_org                  = string<br/>    log_level                 = string<br/>    logging_retention_in_days = string<br/>    github_app = object({<br/>      key_base64     = string<br/>      id             = string<br/>      webhook_secret = string<br/>    })<br/>    runner_iam_role_managed_policy_arns = list(string)<br/>    runner_group_name                   = string<br/>    runner_specs = map(object({<br/>      ami_filter = object({<br/>        name  = list(string)<br/>        state = list(string)<br/>      })<br/>      ami_kms_key_arn = string<br/>      ami_owners      = list(string)<br/>      runner_labels   = list(string)<br/>      extra_labels    = list(string)<br/>      max_instances   = number<br/>      min_run_time    = number<br/>      instance_types  = list(string)<br/>      pool_config = list(object({<br/>        size                         = number<br/>        schedule_expression          = string<br/>        schedule_expression_timezone = string<br/>      }))<br/>      runner_user                   = string<br/>      enable_userdata               = bool<br/>      instance_target_capacity_type = string<br/>      block_device_mappings = list(object({<br/>        delete_on_termination = bool<br/>        device_name           = string<br/>        encrypted             = bool<br/>        iops                  = number<br/>        kms_key_id            = string<br/>        snapshot_id           = string<br/>        throughput            = number<br/>        volume_size           = number<br/>        volume_type           = string<br/>      }))<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_tenant_configs"></a> [tenant\_configs](#input\_tenant\_configs) | n/a | <pre>object({<br/>    ecr_registries = list(string)<br/>    tags           = map(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ec2_runners_ami_name_map"></a> [ec2\_runners\_ami\_name\_map](#output\_ec2\_runners\_ami\_name\_map) | n/a |
| <a name="output_ec2_runners_arn_map"></a> [ec2\_runners\_arn\_map](#output\_ec2\_runners\_arn\_map) | n/a |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | n/a |
| <a name="output_webhook_endpoint"></a> [webhook\_endpoint](#output\_webhook\_endpoint) | n/a |
<!-- END_TF_DOCS -->
