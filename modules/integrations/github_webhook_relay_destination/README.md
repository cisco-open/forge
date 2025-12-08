# Webhook Relay Destination Module

Creates the destination EventBridge bus, grants the source account permission to PutEvents, and wires multiple (or single) Lambda targets via per‑rule event patterns.

## Architecture

```mermaid
graph TD
  SourceAcct[(Source Account<br/>Relay Module)] -- PutEvents --> DestBus[(EventBridge Destination Bus)]

  Policy[Bus Policy<br/>Allow source_account_id<br/>events:PutEvents] -.attached.-> DestBus

  subgraph Destination Account
    DestBus --> R0{{Rule 0..N<br/>for_each target}}
    R0 --> L0[(Lambda Function 0)]
    R0 --> L1[(Lambda Function 1)]
    R0 --> Ln[(Lambda Function n)]
  end

  %% Legend (conceptual)
  SourceAcct:::acct
  DestBus:::bus
  Policy:::policy
  R0:::rule
  L0:::lambda
  L1:::lambda
  Ln:::lambda

  %% Styling

  classDef acct fill:#e6f2ff,stroke:#336699,stroke-width:1px;
  classDef bus fill:#ffe6cc,stroke:#d97b00,stroke-width:1px;
  classDef policy fill:#fafafa,stroke:#555,stroke-dasharray:3 3;
  classDef rule fill:#f7e8ff,stroke:#8040b3,stroke-width:1px;
  classDef lambda fill:#d9f7d9,stroke:#2d7a2d,stroke-width:1px;
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.25 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.25.0 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_bus.destination](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_bus_policy.allow_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus_policy) | resource |
| [aws_cloudwatch_event_rule.receive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.allow_assume_external_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_permission.eventbridge_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_iam_policy_document.allow_assume_external](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [external_external.fetch_secret_value](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS profile to use. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region to use. | `string` | n/a | yes |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | n/a | `map(string)` | n/a | yes |
| <a name="input_reader_config"></a> [reader\_config](#input\_reader\_config) | Configuration for IAM role creation and secret retrieval | <pre>object({<br/>    role_name              = string<br/>    role_trust_principals  = list(string)<br/>    source_secret_role_arn = string<br/>    enable_secret_fetch    = bool<br/>    source_secret_arn      = string<br/>    source_secret_region   = string<br/>  })</pre> | <pre>{<br/>  "enable_secret_fetch": false,<br/>  "role_name": "github-webhook-relay-secret-reader",<br/>  "role_trust_principals": [],<br/>  "source_secret_arn": "",<br/>  "source_secret_region": "",<br/>  "source_secret_role_arn": ""<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_webhook_relay_destination_config"></a> [webhook\_relay\_destination\_config](#input\_webhook\_relay\_destination\_config) | All configuration for the destination EventBridge relay | <pre>object({<br/>    name_prefix                = string<br/>    destination_event_bus_name = string<br/>    source_account_id          = string<br/>    targets = list(object({<br/>      event_pattern       = string<br/>      lambda_function_arn = string<br/>    }))<br/>  })</pre> | <pre>{<br/>  "destination_event_bus_name": "webhook-relay-destination",<br/>  "name_prefix": "webhook-relay-destination",<br/>  "source_account_id": "",<br/>  "targets": []<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Local role ARN. |
| <a name="output_webhook"></a> [webhook](#output\_webhook) | Webhook relay and secret fetched from source account. |
<!-- END_TF_DOCS -->
