# Troubleshooting Without Splunk

Splunk is optional. Every ForgeMT installation should still be debuggable with
GitHub, AWS, CloudWatch, EC2, and Kubernetes tools.

Use this runbook when the Splunk integration modules are not deployed or when
you need to prove the baseline platform before adding observability.

ForgeMT sends baseline platform logs to CloudWatch. That includes Lambda logs,
runner lifecycle logs, webhook handling, and most support signals. Splunk is
not required to inspect those signals.

The exceptions are integration-specific data paths, such as AWS billing and S3
log ingestion modules, where data may go to Splunk directly or through Kinesis
when those Splunk modules are deployed.

## Triage Order

Start with the narrowest boundary:

1. GitHub workflow labels and runner group access
1. GitHub App installation and webhook delivery
1. ForgeMT webhook, queue, and runner lifecycle Lambdas
1. EC2 AMI lookup, subnet capacity, EC2 quotas, and instance profile
1. runner bootstrap logs
1. tenant AWS role trust and permissions
1. ARC controller, pods, Karpenter, storage, and node capacity, if ARC is used

## GitHub Checks

Check the workflow run first:

- Does `runs-on` contain `self-hosted`?
- Do all labels match the generated tenant labels?
- Is the repository included in the GitHub App installation?
- Can the repository use the target runner group?
- Did GitHub send a `workflow_job` webhook for the queued job?

Expected EC2 label shape:

```yaml
runs-on:
  - self-hosted
  - type:small
  - x64
  - ec2
  - tnt:acme
```

Expected ARC label shape:

```yaml
runs-on:
  - self-hosted
  - type:dind
  - x64
  - arc
  - tnt:acme
```

In the GitHub App settings, use the webhook delivery view to inspect the last
`workflow_job` payload and response. A missing delivery usually means the app is
not installed or is not subscribed to `workflow_job`.

## AWS Identity Checks

Confirm the operator or CI profile is using the expected account:

```bash
aws sts get-caller-identity --profile forge-prod
export AWS_PROFILE=forge-prod
```

Confirm the GitHub App key parameter exists:

```bash
aws ssm get-parameter \
  --name /forge/acme-euw1-main/github_app_key \
  --with-decryption \
  --query 'Parameter.{Name:Name,Version:Version,LastModifiedDate:LastModifiedDate}' \
  --output table
```

The value should be the real base64 PEM, not the initial placeholder.

## CloudWatch Logs

List ForgeMT log groups for the tenant prefix:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/acme-euw1-main \
  --query 'logGroups[].logGroupName' \
  --output table
```

Start with log groups whose names include:

- `github-webhook-relay`
- `register-github-app-runner-group`
- `clean-global-lock`
- `job-log-archiver`
- `redrive-deadletter`
- runner lifecycle or scale-up/scale-down functions created by the EC2 module

Search recent errors:

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/acme-euw1-main-github-webhook-relay \
  --start-time "$(date -u -v-1H +%s)000" \
  --filter-pattern '"ERROR" "AccessDenied" "Signature mismatch" "No AMIs found"'
```

On Linux systems without BSD `date`, compute the start time with your normal
shell tooling or omit `--start-time` for a broader search.

## SQS And Dead Letters

Find queues with the tenant prefix:

```bash
aws sqs list-queues --queue-name-prefix acme-euw1-main
```

Check approximate message counts:

```bash
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible ApproximateNumberOfMessagesDelayed
```

If a dead-letter queue has messages, inspect one message body in a non-prod
environment or redrive through the documented platform workflow. Do not purge
queues until you know whether the messages are needed for replay.

## EC2 Runner Checks

If no runner launches:

```bash
aws ec2 describe-images \
  --owners 123456789012 \
  --filters 'Name=name,Values=forge-gh-runner-amd64-v*' 'Name=state,Values=available' \
  --query 'Images[].{ImageId:ImageId,Name:Name,CreationDate:CreationDate}' \
  --output table
```

Check capacity and quotas:

```bash
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters 'Name=instance-type,Values=t3.small,t3.medium'
```

```bash
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A
```

If an EC2 runner starts and disappears, check user data and runner service logs.
Use SSM Session Manager if enabled, or inspect CloudWatch log streams created by
the runner module.

Common EC2 causes:

| Symptom                      | Likely cause                                               |
| ---------------------------- | ---------------------------------------------------------- |
| `No AMIs found`              | wrong `ami_name`, owner account, region, or AMI sharing    |
| capacity errors              | unavailable instance type, Spot/on-demand quota, subnet AZ |
| access denied                | deployment role or runner instance profile policy          |
| runner never registers       | GitHub App key, installation, runner group, or user data   |
| runner registers then no job | labels or runner group access                              |

## Tenant AWS Role Checks

If the job starts but cannot assume a tenant role, inspect the target role trust
policy. The trust must allow the ForgeMT runner role to assume the tenant role,
and any required session tags must be permitted.

From a failing workflow, print the caller identity before assuming the tenant
role:

```yaml
- name: Caller identity
  run: aws sts get-caller-identity
```

Then test the tenant role:

```yaml
- name: Assume tenant role
  run: |
    aws sts assume-role \
      --role-arn "${AWS_ROLE_ARN}" \
      --role-session-name forgemt-smoke
```

Do not add static AWS keys to the workflow to bypass this. Fix the trust path.

## ARC Checks

Run these only when ARC is enabled:

```bash
kubectl get pods -A
kubectl get autoscalingrunnersets -A
kubectl get ephemeralrunners -A
kubectl get nodes -o wide
helm list -A
```

For pending pods:

```bash
kubectl describe pod -n <namespace> <pod-name>
kubectl describe node <node-name>
kubectl get events -A --sort-by=.lastTimestamp
```

Common ARC causes:

| Symptom               | Likely cause                                             |
| --------------------- | -------------------------------------------------------- |
| pod pending           | Karpenter capacity, taints, storage class, CPU/memory    |
| pod rejected          | missing CPU/memory units or invalid runner spec          |
| Docker build fails    | job used `type:k8s` instead of `type:dind`               |
| scale set not found   | ARC controller, Helm release, namespace, or cluster auth |
| AWS auth fails in pod | pod identity or tenant role trust                        |

## When To Add Observability

Do not deploy Splunk just to debug the first tenant. First prove:

- webhook delivery works
- the selected EC2 runner or ARC pod launches
- a smoke workflow completes
- tenant role assumption works
- cleanup removes the runner

After that, add your company observability path. If that path is Splunk, use
[Splunk](../integrations/splunk.md) and the
[Splunk Dashboard Runbook](splunk-dashboard-runbook.md). If your company uses
another platform, forward the same baseline signals: webhook errors, Lambda
errors, queue depth, EC2 capacity errors, ARC pod states, and runner cleanup.

## Signals To Export

If your company uses Datadog, Grafana, New Relic, CloudWatch dashboards,
OpenTelemetry, or another observability stack, start by exporting these signals:

| Signal                      | Baseline source                            | Why it matters                                   |
| --------------------------- | ------------------------------------------ | ------------------------------------------------ |
| GitHub webhook failures     | CloudWatch Lambda logs                     | Shows signature, delivery, and payload issues.   |
| Runner lifecycle errors     | CloudWatch Lambda and runner logs          | Shows registration, scale-up, and cleanup gaps.  |
| Queue depth and DLQ depth   | SQS metrics                                | Shows stuck events and redrive needs.            |
| EC2 capacity and AMI errors | CloudWatch logs plus EC2 API responses     | Shows quota, subnet, AMI, and launch failures.   |
| ARC pod state               | Kubernetes metrics and events              | Shows scheduling, storage, and Karpenter issues. |
| Tenant role failures        | CloudWatch logs and AWS STS errors         | Shows IAM trust or permission gaps.              |
| Cleanup health              | CloudWatch logs and Cloud Custodian output | Shows stale runners, AMIs, and leftovers.        |

CloudWatch should remain the first place to confirm raw platform behavior even
when a richer observability platform is deployed.
