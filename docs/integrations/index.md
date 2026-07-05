# Integrations

Integrations are optional. They connect Forge to external systems, but they are
not required for a first tenant.

| Integration          | Start here                                      | Required for Forge runtime?                                  |
| -------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| Splunk               | [Splunk](splunk.md)                             | No                                                           |
| Teleport             | [Teleport](teleport.md)                         | No                                                           |
| GitHub webhook relay | [GitHub Webhook Relay](github-webhook-relay.md) | Source is platform runtime; destination modules are optional |

If your company uses another logging, metrics, access, or webhook platform,
skip the Forge integration module and wire your own system outside the critical
runner path.
