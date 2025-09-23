# Webhook Relay Destination Module

Creates the destination EventBridge bus, grants the source account permission to PutEvents, and wires multiple (or single) Lambda targets via per‑rule event patterns.

## Architecture

```
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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.1 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.4 |
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
| [aws_cloudwatch_event_bus.destination](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus) | resource |
| [aws_cloudwatch_event_bus_policy.allow_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_bus_policy) | resource |
| [aws_cloudwatch_event_rule.receive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_lambda_permission.allow_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_function.receiver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lambda_function) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_destination_event_bus_name"></a> [destination\_event\_bus\_name](#input\_destination\_event\_bus\_name) | Destination bus name | `string` | `"webhook-relay-destination"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for destination resources | `string` | `"webhook-relay-destination"` | no |
| <a name="input_source_account_id"></a> [source\_account\_id](#input\_source\_account\_id) | Source account allowed to PutEvents | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply | `map(string)` | `{}` | no |
| <a name="input_targets"></a> [targets](#input\_targets) | List of targets. Each object = { event\_pattern = JSON string, lambda\_function\_name = string }.<br/>If empty, legacy event\_pattern + lambda\_function\_name are used. | <pre>list(object({<br/>    event_pattern        = string<br/>    lambda_function_name = string<br/>  }))</pre> | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
