# Common tags we propagate project-wide.
locals {
  application_tags_by_region = merge(
    {
      (var.aws_region) = aws_servicecatalogappregistry_application.this.application_tag
    },
    {
      for region, application in aws_servicecatalogappregistry_application.replica :
      region => application.application_tag
    },
  )

  all_security_tags_by_region = {
    for region in local.all_regions :
    region => merge(
      var.default_tags,
      var.tags,
      local.application_tags_by_region[region],
    )
  }

  all_security_tags = local.all_security_tags_by_region[var.aws_region]

  secret_replica_application_tags = {
    for replica in flatten([
      for secret in local.secrets : [
        for region in var.replica_regions : {
          key         = "${secret.name}:${region}"
          secret_name = secret.name
          region      = region
        }
      ]
    ]) : replica.key => replica
  }
}
