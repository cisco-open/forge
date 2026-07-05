# Inputs And Secrets

This page summarizes the values a platform engineer normally needs to collect.
Module-specific details still live in module READMEs and generated Terraform
docs.

## Platform

| Input                          | Purpose                                                                 |
| ------------------------------ | ----------------------------------------------------------------------- |
| tenant name                    | Stable label and folder name.                                           |
| GitHub org and `ghes_url`      | Use `ghes_url: ''` for GitHub Cloud; set a URL for GHES/on-prem GitHub. |
| GitHub App IDs and private key | GitHub API and runner registration.                                     |
| webhook secret                 | Webhook signature validation.                                           |
| VPC and subnets                | Runner network placement.                                               |
| runner specs                   | EC2 and ARC runner shape.                                               |
| allowed AWS roles              | Tenant job access.                                                      |

## Helpers

| Input                      | Purpose                                   |
| -------------------------- | ----------------------------------------- |
| AMI IDs and owner accounts | AMI sharing and runner specs.             |
| ECR repo names             | Operational containers.                   |
| bucket names               | Artifacts, templates, logs, integrations. |
| cleanup policy settings    | Cloud Custodian scope and retention.      |

## Integrations

| Input                           | Purpose                                    |
| ------------------------------- | ------------------------------------------ |
| Splunk tokens and endpoints     | Only when Splunk modules are deployed.     |
| Teleport endpoint and CA values | Only when Teleport is deployed.            |
| webhook destination settings    | Only when relay destinations are deployed. |

If an integration is skipped, remove its inputs and secrets from your operating
repo.
