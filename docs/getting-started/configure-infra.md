# Configure Infra

`modules/infra` is intentionally small. It contains the foundation Forge needs
when ARC/Kubernetes runners are part of the platform.

Copy from:

```text
examples/deployments/infra
examples/templates/infra
```

## EKS

Use `modules/infra/eks` when Forge owns the EKS cluster for ARC scale sets.

Skip it when:

- you run EC2-only Forge runners
- another platform team already provides EKS
- you are evaluating Forge and want the smallest first deployment

## Files To Change First

```text
examples/deployments/infra/release_versions.yml
examples/deployments/infra/terragrunt/_global_settings/_global.yml
examples/deployments/infra/terragrunt/environments/prod/_environment_wide_settings/_environment.yml
examples/deployments/infra/terragrunt/environments/prod/regions/eu-west-1/eks/config.yml
```

## Apply Check

Before deploying tenants with ARC specs:

```bash
kubectl get nodes
kubectl get pods -A
helm list -A
```

Then confirm the platform deployment can authenticate to the cluster through the
Kubernetes and Helm providers.
