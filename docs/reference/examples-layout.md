# Examples Layout

Forge examples are grouped the same way as the modules.

```text
examples/deployments/
  helpers/
  infra/
  platform/
  integrations/

examples/templates/
  helpers/
  infra/
  platform/
  integrations/
```

## Deployment Roots

| Root           | Purpose                                  | First files to edit                                             |
| -------------- | ---------------------------------------- | --------------------------------------------------------------- |
| `helpers`      | Optional account and operations helpers. | `_global.yml`, environment settings, helper `config.yml` files. |
| `infra`        | EKS foundation for ARC.                  | EKS `config.yml` and region settings.                           |
| `platform`     | Tenant runner runtime.                   | Tenant `config.yml` and `runner_settings.hcl`.                  |
| `integrations` | Optional external integrations.          | Integration-specific `config.yml` files and secrets.            |

## Weekly Validation Order

Apply:

```text
helpers -> infra -> platform -> integrations
```

Destroy:

```text
integrations -> platform -> infra -> helpers
```

If your company skips an optional category, remove it from the weekly matrix
instead of keeping failing placeholder deployments.
