# GitHub Webhook Relay

Forge has two webhook relay concerns.

## Platform Source

The source side is part of the Forge platform runtime:

```text
modules/platform/forge_runners/github_webhook_relay/source
```

It validates GitHub webhook signatures and forwards events from the Forge
tenant platform path.

## Optional Destinations

Destination and receiver modules are optional integrations:

```text
modules/integrations/github_webhook_relay_destination
modules/integrations/github_webhook_relay_destination_receivers
```

Use them when you need centralized webhook forwarding to multiple consumers.
Skip them when Forge can call the target directly or when your company already
has a webhook delivery platform.
