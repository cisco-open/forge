# AMI Management

AMI operations normally use helper modules plus image build repos.

## Modules

| Module                            | Use                                                      |
| --------------------------------- | -------------------------------------------------------- |
| `modules/helpers/ami_policy`      | Account policy support for approved AMI use.             |
| `modules/helpers/ami_sharing`     | Cross-account or cross-region AMI sharing.               |
| `modules/helpers/cloud_custodian` | Cleanup old AMIs, snapshots, and stale runner artifacts. |

## Day-2 Checklist

- Keep the active and previous runner AMI IDs documented.
- Share AMIs before tenant configs reference them.
- Confirm launch permissions in every runner account.
- Clean old AMIs only after no tenant references them.
- Keep snapshots long enough for rollback, then clean them deliberately.

## Tenant Update Flow

1. Build and publish the new AMI.
1. Share the AMI to runner accounts.
1. Update `runner_settings.hcl`.
1. Plan and apply one tenant first.
1. Run a workflow smoke test.
1. Roll out to more tenants.
