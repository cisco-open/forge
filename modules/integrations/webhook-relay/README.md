# Webhook Relay (Source & Destination)

Generic cross-account EventBridge webhook relay pattern (HTTP API -> EventBridge -> cross-account bus -> Lambda targets).

## Architecture

1. Source module:
   - API Gateway HTTP API (v2) route `/webhook`
   - Direct AWS service integration: EventBridge `PutEvents` (integration_subtype = EventBridge-PutEvents)
   - Event placed on a **source event bus**
   - Rule forwards matching events to **destination (remote) bus** (cross-account)

2. Destination module:
   - Creates (or references by name) the destination event bus
   - Bus policy allows the source account to `PutEvents`
   - Multiple rules (one per target entry) each with its own event pattern
   - Each rule targets an existing Lambda function

Flow:
Client POST -> HTTP API -> EventBridge (source bus) -> Forwarding rule -> Destination bus -> Rules (per target) -> Lambda(s)
