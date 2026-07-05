# Troubleshooting

Start with the symptom and check the narrowest boundary first.

| Symptom                            | Check                                                                                                                                    |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Job stays queued                   | GitHub App installation, runner group access, exact labels, tenant name.                                                                 |
| EC2 runner starts then disappears  | Runner registration logs, GitHub token generation, instance profile, webhook delivery.                                                   |
| ARC scale set does not create pods | Kubernetes provider auth, ARC controller, namespace, Helm release, Karpenter capacity.                                                   |
| Docker build fails on ARC          | Use `type:dind`; `type:k8s` is not for Docker daemon workloads.                                                                          |
| AWS assume role fails              | Tenant allowed role list, target role trust, role chaining, STS region.                                                                  |
| Webhook signature fails            | GitHub webhook secret, header forwarding, relay configuration.                                                                           |
| Splunk dashboards missing          | Deploy only if Splunk modules are enabled; then check Splunk API token and saved search module.                                          |
| Splunk dashboard data missing      | Check [Splunk Dashboard Runbook](splunk-dashboard-runbook.md), then start with Forge Ingestion Quality before diagnosing Forge behavior. |
| Unsure which dashboard to use      | Start with [Splunk Dashboard Runbook](splunk-dashboard-runbook.md), then move to the narrow subsystem dashboard.                         |
| AMI not found                      | Region, account launch permission, AMI sharing helper, and runner architecture.                                                          |

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
