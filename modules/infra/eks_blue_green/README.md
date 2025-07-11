<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.90 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_blue"></a> [blue](#module\_blue) | ../eks | n/a |
| <a name="module_green"></a> [green](#module\_green) | ../eks | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Default AWS region. | `string` | n/a | yes |
| <a name="input_clusters"></a> [clusters](#input\_clusters) | n/a | <pre>object({<br/>    blue = object({<br/>      tags            = map(string)<br/>      cluster_name    = string<br/>      cluster_version = string<br/>      cluster_size = object({<br/>        instance_type = string<br/>        min_size      = number<br/>        max_size      = number<br/>        desired_size  = number<br/>      })<br/>      cluster_volume = object({<br/>        size       = number<br/>        iops       = number<br/>        throughput = number<br/>        type       = string<br/>      })<br/>      subnet_ids         = list(string)<br/>      vpc_id             = string<br/>      cluster_ami_filter = list(string)<br/>      cluster_ami_owners = list(string)<br/>    })<br/>    green = object({<br/>      tags            = map(string)<br/>      cluster_name    = string<br/>      cluster_version = string<br/>      cluster_size = object({<br/>        instance_type = string<br/>        min_size      = number<br/>        max_size      = number<br/>        desired_size  = number<br/>      })<br/>      cluster_volume = object({<br/>        size       = number<br/>        iops       = number<br/>        throughput = number<br/>        type       = string<br/>      })<br/>      subnet_ids         = list(string)<br/>      vpc_id             = string<br/>      cluster_ami_filter = list(string)<br/>      cluster_ami_owners = list(string)<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to resources. | `map(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
