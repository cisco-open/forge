# Infra / EKS Deployment

Deploy this only when you need ARC/Kubernetes runner scale sets. EC2-only Forge
tenants can skip this deployment.

Deploy root:

```text
examples/deployments/infra/terragrunt
```

Module:

```text
modules/infra/eks
```

______________________________________________________________________

## What You Edit

| File                                                                    | Change                                                                  |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `_global_settings/_global.yml`                                          | Team, product, project, GitHub org, and owner defaults.                 |
| `environments/prod/_environment_wide_settings/_environment.yml`         | AWS account, default region, AWS profile, and remote state.             |
| `environments/prod/regions/eu-west-1/_region_wide_settings/_region.hcl` | AWS region and short region alias.                                      |
| `environments/prod/regions/eu-west-1/eks/config.yml`                    | VPC, subnets, cluster name, Karpenter, Calico, node, and access config. |
| `release_versions.yml`                                                  | Forge module source, ref, and `modules/infra/eks` path.                 |

Templates live under `examples/templates/infra`.

______________________________________________________________________

## First EKS Stack

For the first EKS stack, edit the existing example files in
`environments/prod/regions/eu-west-1/eks`.

To add another region, copy the working shape and then edit the new files:

```bash
export ENV=prod
export SOURCE_REGION=eu-west-1
export REGION=us-east-1
export INFRA_ROOT=examples/deployments/infra/terragrunt
export EKS_DIR="$INFRA_ROOT/environments/$ENV/regions/$REGION/eks"

mkdir -p "$EKS_DIR"
cp examples/templates/infra/eks/config.yml "$EKS_DIR/config.yml"
cp "$INFRA_ROOT/environments/$ENV/regions/$SOURCE_REGION/eks/config.hcl" "$EKS_DIR/config.hcl"
cp "$INFRA_ROOT/environments/$ENV/regions/$SOURCE_REGION/eks/terragrunt.hcl" "$EKS_DIR/terragrunt.hcl"
```

______________________________________________________________________

## Deploy

Deploy the EKS stack directly:

```bash
cd examples/deployments/infra/terragrunt/environments/prod/regions/eu-west-1/eks
terragrunt plan
terragrunt apply
```

Plan the whole infra environment only after the single stack works:

```bash
cd examples/deployments/infra/terragrunt/environments/prod
terragrunt plan --all
```

______________________________________________________________________

## Hand Off to Platform

After EKS is ready:

1. Set the tenant `arc_cluster_name` to the cluster name.
1. Add `arc_runner_specs` in the tenant `config.yml`.
1. Confirm the CI role that applies the tenant can authenticate to Kubernetes.
1. Apply the tenant from the platform deployment root.

If your company already owns EKS, skip this deployment and point the platform
tenant config at the existing cluster.
