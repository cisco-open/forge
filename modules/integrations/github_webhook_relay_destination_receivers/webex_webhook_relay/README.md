# GitHub Webhook Relay Destination Receivers Example

This example composes the `github_webhook_relay_destination` Forge integration module with one or more Lambda receiver functions. It demonstrates how to deploy a Lambda that reacts to forwarded GitHub webhook events (via EventBridge) and can relay messages (e.g. to Webex) using a secure bot token stored in AWS Secrets Manager.

## Overview

Resources provisioned:
- EventBridge destination bus + rules (via `github_webhook_relay_destination` module)
- IAM secret reader role for controlled access to the bot token (optional depending on `reader_config`)
- Lambda function `webex_webhook_relay` (Python 3.12) with log retention and environment wiring
- Required permissions and tagging

Event flow:
1. GitHub webhook is ingested upstream (outside this example) and forwarded onto an EventBridge bus.
2. Destination bus rules match the desired events (here: `detail.action == completed`).
3. The matched event triggers the `webex_webhook_relay` Lambda.
4. The Lambda reads the Webex bot token from Secrets Manager and performs the relay logic.

## Requirements

Before applying this example you must have:
- OpenTofu `~> 1.10` (or Terraform compatible if migrating) and AWS provider `~> 6.0`.
- AWS credentials/profile able to create EventBridge, Lambda, IAM, and Secrets Manager resources.
- Existing GitHub webhook relay pipeline that sends events to the source account & bus referenced.
- A Secrets Manager secret containing the Webex bot token at the exact name:
  - `/cicd/common/webex_webhook_relay_bot_token`
- (Optional) A source secret reader role / secret if cross-account fetching is enabled via `reader_config`.

## Mandatory Secret

The Lambda `webex_webhook_relay` expects an environment variable `WEBEX_BOT_TOKEN_SECRET_NAME` which points to the secret name. This example sets it to `/cicd/common/webex_webhook_relay_bot_token`.

Secret value format (JSON string):

```json
{
  "token": "<webex_bot_token>",
  "room_id": "<webex_room_id>"
}
```

Both `token` and `room_id` keys are required. The function will prepend `Bearer ` to `token` automatically if not present.


<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
