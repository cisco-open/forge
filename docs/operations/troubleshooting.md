# Troubleshooting

Start with the symptom and check the narrowest boundary first.

| Symptom                            | Check                                                                                                                                                                                     |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Job stays queued                   | Check workflow labels, runner group access, GitHub App installation, and `workflow_job` delivery. See [Troubleshooting Without Splunk](troubleshooting-without-splunk.md).                |
| EC2 runner starts then disappears  | Check lifecycle logs, user data, runner service logs, instance profile, and GitHub registration. See [Troubleshooting Without Splunk](troubleshooting-without-splunk.md).                 |
| ARC scale set does not create pods | Check `autoscalingrunnersets`, `ephemeralrunners`, Kubernetes events, Helm, and Karpenter. See [Troubleshooting Without Splunk](troubleshooting-without-splunk.md).                       |
| Docker build fails on ARC          | Use `type:dind`; `type:k8s` is not for Docker daemon workloads.                                                                                                                           |
| AWS assume role fails              | Check caller identity, tenant allowed role list, target role trust, session tags, and STS region. See [Tenant AWS Role Checks](troubleshooting-without-splunk.md#tenant-aws-role-checks). |
| Webhook signature fails            | See [Webhook Signature Fails](#webhook-signature-fails).                                                                                                                                  |
| Splunk dashboards missing          | Deploy only if Splunk modules are enabled; then check Splunk API token and saved search module.                                                                                           |
| Splunk dashboard data missing      | Check [Splunk Dashboard Runbook](splunk-dashboard-runbook.md), then start with Forge Ingestion Quality before diagnosing Forge behavior.                                                  |
| Unsure which dashboard to use      | Start with [Splunk Dashboard Runbook](splunk-dashboard-runbook.md), then move to the narrow subsystem dashboard.                                                                          |
| AMI not found                      | See [AMI Not Found](#ami-not-found). Confirm Region, owner, name pattern, architecture, and launch permission.                                                                            |
| Terraform/Terragrunt appears stuck | See [Terraform/Terragrunt Stuck Runbook](terraform-terragrunt-stuck-runbook.md).                                                                                                          |

## First Commands

```bash
aws sts get-caller-identity
terragrunt plan
```

For ARC:

```bash
kubectl get pods -A
kubectl get autoscalingrunnersets -A
helm list -A
```

For GitHub, inspect the workflow run, runner group, and app installation before
changing Terraform.

## Webhook Signature Fails

Start with the GitHub App webhook delivery, not Terraform.

1. In the GitHub App webhook delivery view, confirm the failing delivery is a
   `workflow_job` event and record the response code, response body, delivery
   ID, and delivery timestamp.

1. Confirm GitHub sent `X-Hub-Signature-256`, `X-GitHub-Event`, and
   `X-GitHub-Delivery`.

1. Confirm the webhook secret configured in GitHub matches the secret consumed by
   Forge. If a relay is in the path, it must forward the raw request body and
   signature header unchanged.

1. Check recent webhook or relay logs:

   ```bash
   aws logs filter-log-events \
     --log-group-name <webhook-or-relay-log-group> \
     --start-time "$(date -u -v-1H +%s)000" \
     --filter-pattern '"signature" "webhook" "ERROR"'
   ```

Signature validation uses the raw request body. Do not reformat or reserialize
the JSON payload when testing the signature path.

## AMI Not Found

Start with the exact Region, AMI owner, and AMI name pattern used by the runner
spec.

```bash
export AWS_REGION="<runner-region>"
export AMI_OWNER="<ami-owner-account-id>"
export AMI_NAME="<ami-name-pattern>"

aws ec2 describe-images \
  --region "$AWS_REGION" \
  --owners "$AMI_OWNER" \
  --filters "Name=name,Values=$AMI_NAME" "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate)[].{id:ImageId,name:Name,arch:Architecture,state:State,created:CreationDate}' \
  --output table
```

If the AMI exists, confirm launch permission for the runner account:

```bash
export AMI_ID="<ami-id>"

aws ec2 describe-image-attribute \
  --region "$AWS_REGION" \
  --image-id "$AMI_ID" \
  --attribute launchPermission
```

If the AMI still does not resolve, compare the runner spec with
[AMI Management](ami-management.md) and [Runner Images](runner-images.md). The
usual causes are wrong Region, wrong owner account, stale name pattern, missing
cross-account launch permission, architecture mismatch, or an AMI cleanup job
removing an image still referenced by a tenant.
