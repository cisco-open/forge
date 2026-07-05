# Configure Integrations

Integrations are optional. Do not deploy them until the platform tenant can run
a job.

Copy from:

```text
examples/deployments/integrations
examples/templates/integrations
```

## Integration Matrix

| Integration               | Module family                       | Deploy when                                                            | Skip when                                                              |
| ------------------------- | ----------------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Splunk Cloud              | `splunk_cloud_*`, `splunk_secrets`  | You use Splunk Cloud dashboards, HEC, saved searches, or data manager. | You use another logging platform.                                      |
| Splunk Observability      | `splunk_o11y_*`                     | You use Splunk Observability for AWS or EKS metrics.                   | You use another metrics platform.                                      |
| OpenCost for Splunk       | `splunk_opencost_eks`               | EKS cost data should go to Splunk.                                     | You do not run ARC/EKS or do not use Splunk.                           |
| Teleport                  | `teleport`                          | Operators need Teleport access/audit for EKS.                          | Access is handled another way.                                         |
| Webhook relay destination | `github_webhook_relay_destination*` | You centralize GitHub webhook forwarding.                              | The platform source can call receivers directly or no relay is needed. |

## Files To Change First

```text
examples/deployments/integrations/release_versions.yml
examples/deployments/integrations/terragrunt/_global_settings/_global.yml
examples/deployments/integrations/terragrunt/environments/prod/_environment_wide_settings/_environment.yml
```

Then edit only the integration folder you are deploying.

## Skip Rule

If an integration is not used, delete it from your operating repo instead of
leaving placeholder secrets and failing plans.
