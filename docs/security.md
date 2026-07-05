# Security

ForgeMT deploys runner infrastructure into your AWS environment. It is not a
security certification or a substitute for your company controls. The platform
team is responsible for reviewing IAM, network placement, secrets, images,
workflow permissions, and tenant access before production use.

## Security Model

| Area            | Forge expectation                                                                                   |
| --------------- | --------------------------------------------------------------------------------------------------- |
| GitHub identity | Use a GitHub App with the minimum permissions needed for runner registration and webhook events.    |
| Webhooks        | Accept signed GitHub events only through the configured ForgeMT webhook path.                       |
| AWS identity    | Prefer short-lived AWS access through OIDC and scoped IAM roles instead of static AWS keys.         |
| Runner lifetime | Prefer ephemeral runners so each job gets a fresh environment.                                      |
| Tenant boundary | Keep tenant metadata, labels, IAM roles, VPC/subnet choices, and ARC namespaces explicit in config. |
| Secrets         | Store GitHub App and integration secrets in the approved secret store, not in Terragrunt YAML.      |
| Images          | Build, patch, scan, and retire runner images through repeatable image pipelines.                    |
| Integrations    | Treat Splunk, Teleport, and relay destinations as separate trust boundaries with their own secrets. |

## GitHub App And Webhook Controls

The GitHub App is the trust entry point for runner registration and webhook
events. Before production:

- grant only the permissions required by your runner mode
- subscribe only to the events Forge needs
- store the private key and webhook secret outside source control
- rotate GitHub App credentials through the platform secrets process
- confirm webhook signature verification is enabled on the ForgeMT path
- install the app only where ForgeMT runners should be available

If a tenant should not use ForgeMT, do not rely only on documentation. Keep the
GitHub App installation, runner group, labels, and AWS roles aligned.

Validate the key parameter and app metadata before production:

```bash
aws ssm get-parameter \
  --name /forge/acme-euw1-main/github_app_key \
  --with-decryption \
  --query 'Parameter.{Name:Name,Version:Version,LastModifiedDate:LastModifiedDate}' \
  --output table
```

The parameter value must be the real base64 PEM, not the placeholder created by
the targeted first apply.

## AWS Access

Tenant workflows should assume AWS roles through OIDC. This keeps long-lived
cloud credentials out of GitHub repositories and runner hosts.

For each tenant, review:

- which GitHub organization, repository, environment, branch, or workflow can
  assume the role
- which AWS account and region the role can access
- whether the role can only access the resources required by the tenant
- whether permission boundaries or SCPs are needed in your account model
- whether logs show the assumed role session clearly enough for audit

The [First Tenant](getting-started/first-tenant.md) and
[Tenant Onboarding](operations/tenant-onboarding.md) pages describe the
onboarding flow.

Validate tenant role assumption from a smoke workflow:

```yaml
- name: Caller identity before tenant role
  run: aws sts get-caller-identity

- name: Assume tenant role
  run: |
    aws sts assume-role \
      --role-arn arn:aws:iam::123456789012:role/role_for_forge_runners \
      --role-session-name forgemt-security-check
```

## EC2 Runner Isolation

EC2 runners are a good fit for strong job isolation and custom tooling, but the
AMI becomes part of the security boundary.

Before allowing production workloads:

- build runner AMIs from a known base image
- pin runner and tool versions where repeatability matters
- enable OS patching and image rebuild cadence
- include only required tools and credentials
- remove bootstrap secrets from disk
- verify runner cleanup and scale-down behavior
- retire old AMIs through AMI policy, AMI sharing, and Cloud Custodian jobs

Use [Runner Images](operations/runner-images.md),
[AMI Management](operations/ami-management.md), and
[Cloud Custodian](operations/cloud-custodian.md) for the operating paths.

Validate the AMI before adding it to a tenant config:

```bash
aws ec2 describe-images \
  --owners 123456789012 \
  --filters 'Name=name,Values=forge-gh-runner-amd64-v*' 'Name=state,Values=available' \
  --query 'Images[].{ImageId:ImageId,Name:Name,CreationDate:CreationDate}' \
  --output table
```

## ARC And EKS Isolation

ARC runners introduce Kubernetes controls into the trust boundary.

Before enabling ARC tenants:

- decide whether tenants share nodes or require dedicated node pools
- review namespaces, service accounts, pod identity, and network policy
- pin runner and sidecar images from an approved registry
- limit privileged containers to workloads that explicitly require them
- keep cluster add-ons, Karpenter, Calico, EBS CSI, and ARC versions current
- validate that tenant AWS access still uses the expected OIDC path

Use [Configure Infra](getting-started/configure-infra.md) before deploying
tenant ARC runner specs.

Validate ARC before onboarding a tenant to it:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get autoscalingrunnersets -A
helm list -A
```

## Optional Integration Risk

Optional integrations often need powerful credentials. Deploy them deliberately.

| Integration   | Security question before deploying                                                  |
| ------------- | ----------------------------------------------------------------------------------- |
| Splunk        | Which tokens, HEC endpoints, indexes, dashboards, saved searches, and alerts exist? |
| OpenTelemetry | Which metrics/logs leave the AWS account and who owns retention?                    |
| OpenCost      | Which cost dimensions are exposed and to whom?                                      |
| Teleport      | Which operators can access clusters and how is access audited?                      |
| Webhook relay | Which receivers get GitHub events and how are signatures preserved or revalidated?  |

If the answer is unclear, skip the integration until the owner and secret path
are defined.

## Production Readiness Checklist

- One EC2 runner smoke workflow succeeds.
- One ARC runner smoke workflow succeeds, if ARC is enabled.
- Tenant AWS role assumption works without static AWS keys.
- GitHub App permissions and installations match the tenant scope.
- Runner images are built from approved sources and have an owner.
- Helper modules are either deployed or intentionally skipped.
- Optional integrations are either tested or deleted from the operating repo.
- Weekly example validation covers every enabled category.
- Cleanup jobs handle stale runners, AMIs, ECR images, and leftover resources.
- Support engineers know where to check GitHub, AWS, runner logs, and optional
  observability dashboards.

For environments without Splunk, the baseline support path is
[Troubleshooting Without Splunk](operations/troubleshooting-without-splunk.md).
