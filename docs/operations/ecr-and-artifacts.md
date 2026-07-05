# ECR And Artifacts

Use `modules/helpers/ecr` when Forge owns operational ECR repositories. Use an
external registry when your company already has a container platform.

## Common Repositories

| Repository       | Used for                                              |
| ---------------- | ----------------------------------------------------- |
| runner image     | ARC runner container image                            |
| dind image       | Docker-in-Docker sidecar or DinD runner image         |
| pre-commit image | lint and validation jobs                              |
| helper image     | scheduled jobs, release tools, or automation wrappers |

## Blueprint

Copy from:

```text
docs/operations/repo-blueprints/containers
```

## Operating Rules

- Tag images immutably with semantic versions or commit SHAs.
- Keep `latest` out of production runner specs.
- Enable scanning in your registry.
- Keep ECR lifecycle policies aligned with rollback needs.
- Give tenants pull access only to repositories they need.
