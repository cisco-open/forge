# Operations Secrets

Keep secrets boring: stable names, clear owners, narrow access, and documented
rotation steps.

## Required Platform Secrets

| Secret                     | Used by                                      |
| -------------------------- | -------------------------------------------- |
| GitHub App ID              | Platform tenant module and webhook handlers. |
| GitHub App installation ID | Runner registration and GitHub API calls.    |
| GitHub App private key     | Runner registration and GitHub API calls.    |
| GitHub webhook secret      | Webhook signature validation.                |
| SSM private key parameter  | EC2 runner module integration.               |

## Optional Integration Secrets

Splunk, Teleport, webhook relay destinations, and other integrations may need
their own secrets. If the integration is not deployed, do not create placeholder
secrets.

## Rotation Flow

1. Create the new secret version.
1. Plan the affected platform or integration stack.
1. Apply during a low-risk window.
1. Run a workflow smoke test.
1. Remove or disable the old secret version after rollback risk is gone.
