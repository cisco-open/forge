locals {
  all_security_tags = merge(var.default_tags, var.tags)

  redelivery_tenant_configs = [
    for tenant_config in var.redelivery_config.tenant_configs : merge(tenant_config, {
      github_api         = tenant_config.gh_config.ghes_url == "" ? "https://api.github.com" : "${tenant_config.gh_config.ghes_url}/api/v3"
      github_api_version = coalesce(tenant_config.github_api_version, "2022-11-28")
    })
  ]
}
