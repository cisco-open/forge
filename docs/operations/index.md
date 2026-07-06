# Operations

This section is for the platform team after the first Forge tenant is running.
It covers tenant support, image management, artifacts, cleanup, secrets,
upgrades, and troubleshooting.

## Day-2 Loop

| Cadence              | Action                                                                     | Doc                                                                         |
| -------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Every tenant request | Collect tenant values, add config, run plan, run smoke workflow.           | [Tenant Onboarding](tenant-onboarding.md)                                   |
| Every image release  | Build base/custom images, share AMIs, update tenant runner specs.          | [Runner Images](runner-images.md)                                           |
| Weekly               | Run example apply/destroy for helpers, infra, platform, integrations.      | [Workflow Blueprints](workflows/index.md)                                   |
| Weekly               | Run cleanup and policy jobs.                                               | [Cloud Custodian](cloud-custodian.md)                                       |
| Monthly              | Review module refs, Renovate output, AMI age, stale ECR tags, and secrets. | [Upgrades](upgrades.md)                                                     |
| Planned ARC upgrade  | Rebuild blue/green EKS clusters and move tenants one at a time.            | [Move ARC Tenants](move-arc-tenants.md)                                     |
| Incident             | Triage queued jobs, failed runner registration, IAM, webhooks, or ARC.     | [Troubleshooting](troubleshooting.md)                                       |
| Incident             | Debug Terraform, OpenTofu, or Terragrunt plan/apply that appears stuck.    | [Terraform/Terragrunt Stuck Runbook](terraform-terragrunt-stuck-runbook.md) |
| Incident             | Use Splunk dashboards to identify the failing subsystem and severity.      | [Splunk Dashboard Runbook](splunk-dashboard-runbook.md)                     |

## Operating Repos

If you need an end-to-end operating model, copy from
[Operations Repo Blueprints](repo-blueprints/index.md). The blueprints include
real folders for Packer, Ansible, containers, Renovate, Cloud Custodian,
Terragrunt, reusable actions, and weekly example deployments.

For Splunk-based operations, start with the
[Splunk Dashboard Runbook](splunk-dashboard-runbook.md). Use the
[panel reference](splunk-dashboard-panel-reference.md) when you need to map a
dashboard panel back to its operational question.

For installations that do not deploy Splunk, use
[Troubleshooting Without Splunk](troubleshooting-without-splunk.md) as the
baseline support runbook.
