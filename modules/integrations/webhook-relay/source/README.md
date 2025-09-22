<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.90 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.14.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_apigatewayv2_api.webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.post_hook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_event_bus.source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_rule.forward](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.dest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.apigw_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.events_forward](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.apigw_put_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.events_forward_put](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_destination_account_id"></a> [destination\_account\_id](#input\_destination\_account\_id) | Destination (receiver) AWS account ID | `string` | n/a | yes |
| <a name="input_destination_event_bus_name"></a> [destination\_event\_bus\_name](#input\_destination\_event\_bus\_name) | Destination bus name in destination account | `string` | n/a | yes |
| <a name="input_destination_region"></a> [destination\_region](#input\_destination\_region) | Destination region (omit for same as source) | `string` | `null` | no |
| <a name="input_event_source"></a> [event\_source](#input\_event\_source) | EventBridge source field for emitted events | `string` | `"webhook.relay"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for created resources | `string` | `"webhook-relay-source"` | no |
| <a name="input_source_event_bus_name"></a> [source\_event\_bus\_name](#input\_source\_event\_bus\_name) | Name of the source EventBridge bus | `string` | `"webhook-relay-source"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_event_source"></a> [event\_source](#output\_event\_source) | EventBridge source field value |
| <a name="output_source_event_bus_arn"></a> [source\_event\_bus\_arn](#output\_source\_event\_bus\_arn) | Source bus ARN |
| <a name="output_source_event_bus_name"></a> [source\_event\_bus\_name](#output\_source\_event\_bus\_name) | Source bus name |
| <a name="output_webhook_endpoint"></a> [webhook\_endpoint](#output\_webhook\_endpoint) | Public webhook URL |
<!-- END_TF_DOCS -->
