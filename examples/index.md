# 🧩 Forge Example Deployments

This directory contains **ready-to-use, real-world examples** for deploying Forge in various AWS environments. Each example demonstrates best practices for multi-tenant, secure, and observable CI/CD infrastructure using Forge modules and Terragrunt.

---

## 📚 Available Examples

| Example Folder                | Description                                                                                   |
|-------------------------------|----------------------------------------------------------------------------------------------|
| [`infra-forge`](./infra-forge) | Standalone Forge infrastructure setup: VPC, EKS, IAM, secrets, billing, and more.            |
| [`forge_with_integrations`](./forge_with_integrations) | Forge with integrations for Splunk, Teleport, and other observability/security tools.      |

---

## 🏗️ How to Use

1. **Pick an example** that matches your use case.
2. **Read the `index.md` or `README.md`** in the example folder for scenario-specific instructions and module overviews.
3. **Replace all `<ADD YOUR VALUE>` placeholders** with your actual configuration (tokens, ARNs, IDs, etc).
4. **Create required secrets** in AWS Secrets Manager (see [`docs/configurations/secrets.md`](../docs/configurations/secrets.md)).
5. **Apply with Terragrunt**:
   ```bash
   terragrunt run-all plan
   terragrunt run-all apply
   ```

---

## 🔗 More Resources

- [Forge Documentation](https://cisco-open.github.io/forge/)
- [Configuration Reference](../docs/configurations/)
- [Module Reference](https://github.com/cisco-open/forge/tree/main/modules/)

---

> **Tip:**  
> Always review the example's prerequisites and dependencies before applying.  
> For questions or help, open an issue or discussion in the [Forge GitHub repository](https://github.com/cisco-open/forge).
