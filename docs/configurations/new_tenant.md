# Adding a New Tenant to Forge

This guide explains how to add a new tenant in Forge, configure required files, set up GitHub App secrets, and deploy the configuration.

---

## 1. Create Tenant Configuration

- Add a new tenant entry in:
  ```
  terragrunt/_global_settings/tenants/
  ```
- Create the following Terragrunt files for your tenant:
  ```
  terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name>/terragrunt.hcl
  terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name>/runner_settings.hcl
  ```
- If using Teleport, add the tenant name to:
  ```
  terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/teleport/config.hcl
  ```

---

## 2. Create a GitHub App

- Create a new GitHub App for the tenant in your GitHub organization.
- Use a **fake webhook URL** such as `https://example.com` and set as active.
- Generate a private key for the app (download and save the PEM file).
- Select the permissions below for your GitHub App:

| Type         | Permission           | Access      |
|--------------|---------------------|-------------|
| Repository   | Actions              | Read-only   |
| Repository   | Actions Metadata     | Read-only   |
| Repository   | Checks               | Read-only   |
| Organization | Administration       | Read/Write  |
| Organization | Self-hosted runners  | Read/Write  |
| Events       | Workflow job         | Subscribe   |

- Install the app into your target organization or a specific repository.
- Collect the following information from your GitHub App settings:
  - **GitHub App Client ID**
  - **GitHub App Name**
  - **GitHub App ID**
  - **GitHub App Private key** (path to the PEM file)
  - **GitHub App Installation ID**

**Permission table notes:**
- **Repository permissions** allow the app to read workflow and job information.
- **Organization permissions** are required to manage and register self-hosted runners.
- **Events** subscription enables the app to receive workflow job events, which are necessary for runner orchestration.

---

## 3. Deploy Secrets

Navigate to your tenant directory and deploy the secrets:

```sh
cd terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name>
terragrunt apply --target aws_secretsmanager_secret_version.cicd_secrets
```

---

## 4. Set GitHub App Secrets

Use the script to set the required GitHub App secrets:

```sh
./scripts/update-github-app-secrets.sh /path/to/terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name> client_id Ab12cd34EfGh56ij78KL  # GitHub App Client ID
./scripts/update-github-app-secrets.sh /path/to/terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name> name forge-use1                # GitHub App Name
./scripts/update-github-app-secrets.sh /path/to/terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name> id 1234567                     # GitHub App ID
./scripts/update-github-app-secrets.sh /path/to/terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name> key /path/to/private-key.pem   # GitHub App Private key
./scripts/update-github-app-secrets.sh /path/to/terragrunt/environments/<aws account alias>/regions/<aws region>/vpcs/<vpc alias>/tenants/<tenant_name> installation_id 11223344        # GitHub App Installation ID
```

You can run these commands in parallel by appending `&` at the end of each line.

---

## 5. Deploy All Tenant Resources

After secrets are set, deploy all resources for the tenant:

```sh
cd examples/forge_with_integrations/terragrunt/environments/prod/regions/<aws region>/vpcs/sl/tenants/<tenant_name>
terragrunt apply
```

---

## Notes

- Use the actual **GitHub App ID** for `id`, the **GitHub App Client ID** for `client_id`, and the **App Installation ID** for `installation_id`.
- The `key` value should be the path to your GitHub App's private key PEM file.
- Replace example values with your actual tenant path and secret values.
- This process is typically used during onboarding of a new tenant to Forge.
