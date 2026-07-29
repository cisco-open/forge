# Common tags we propagate project-wide.
locals {
  all_security_tags = merge(var.default_tags, var.tags)

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
