locals {
  all_security_tags = merge(var.default_tags, var.tags)

  redelivery_tenant_configs = [
    for tenant_config in var.redelivery_config.tenant_configs : {
      tenant             = tenant_config.tenant
      prefixes           = tenant_config.prefixes
      github_api         = tenant_config.gh_config.ghes_url == "" ? "https://api.github.com" : "${tenant_config.gh_config.ghes_url}/api/v3"
      github_api_version = coalesce(tenant_config.github_api_version, "2022-11-28")
    }
  ]

  redelivery_tenant_config_parameter_prefix = "/forge/${var.name_prefix}/tenant-configs"
  redelivery_tenant_configs_json            = jsonencode(local.redelivery_tenant_configs)
  redelivery_tenant_config_chunk_size       = 3500
  redelivery_tenant_config_chunk_count      = ceil(length(local.redelivery_tenant_configs_json) / local.redelivery_tenant_config_chunk_size)
  redelivery_tenant_config_chunks = [
    for index in range(local.redelivery_tenant_config_chunk_count) :
    substr(local.redelivery_tenant_configs_json, index * local.redelivery_tenant_config_chunk_size, local.redelivery_tenant_config_chunk_size)
  ]
}
