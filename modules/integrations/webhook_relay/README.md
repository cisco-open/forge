# Webhook Relay (Source & Destination)

Generic cross-account EventBridge webhook relay pattern (HTTP API -> EventBridge -> cross-account bus -> Lambda targets).

## Architecture

```mermaid
flowchart LR
  %% Source Account (Sender)
  subgraph SA[Source Account]
    Client[[Webhook Client]]
    API[API Gateway HTTP API<br/>Route: POST /webhook]
    Int[(Service Integration<br/>EventBridge-PutEvents)]
    SrcBus[(EventBridge Source Bus)]
    FwdRule{{Forwarding Rule<br/>pattern: source = var.event_source}}
    RoleAPI[(IAM Role apigw-events)]
    RoleFwd[(IAM Role events-forward)]
    Client --> API --> Int --> SrcBus --> FwdRule
    API -.-> RoleAPI
    RoleAPI -.-> SrcBus
    FwdRule -.-> RoleFwd
  end

  %% Destination Account (Receiver)
  subgraph DA[Destination Account]
    DestBus[(Destination EventBridge Bus)]
    subgraph Rules[Per-Target Rules]
      RuleN{{Rule 0..N<br/>event_pattern}}
    end
    Lambda1[(Lambda Fn A)]
    Lambda2[(Lambda Fn B)]
    LambdaN[(Lambda Fn N)]
  end

  RoleFwd -.-> DestBus
  DestBus --> RuleN --> Lambda1
  RuleN --> Lambda2
  RuleN --> LambdaN

  %% Cross-account bus policy relation
  Policy[(Bus Policy<br/>Allow source_account_id<br/>events:PutEvents)]
  Policy -.-> DestBus

  %% Styling
  classDef bus fill:#ffe6cc,stroke:#d97b00,stroke-width:1px;
  classDef rule fill:#f7e8ff,stroke:#8040b3,stroke-width:1px;
  classDef role fill:#e6f2ff,stroke:#336699,stroke-width:1px;
  classDef lambda fill:#d9f7d9,stroke:#2d7a2d,stroke-width:1px;
  classDef integ fill:#eef,stroke:#669;
  class SrcBus,DestBus bus
  class FwdRule,RuleN rule
  class RoleAPI,RoleFwd role
  class Lambda1,Lambda2,LambdaN lambda
  class Int integ
```

## End-to-End Flow

1. Client POST /webhook (JSON body)
2. API Gateway service integration calls EventBridge PutEvents (no Lambda)
3. Event lands on source bus with Source = var.event_source
4. Forwarding rule matches and uses its IAM role to PutEvents to destination bus
5. Destination bus policy authorizes source account (optionally narrowed by principal ARN)
6. Per-target rules match subsets (event_pattern) and invoke existing Lambdas

## Deployment Model

- Source module: exposes webhook endpoint + forwards to destination bus
- Destination module: creates bus, policy, N rules targeting existing Lambdas
- Add/remove targets by editing the targets list and reapplying
