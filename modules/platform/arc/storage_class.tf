locals {
  # ForgeModuleRef changes on every Forge release. Keeping it in the EBS tag
  # parameters makes the immutable StorageClass change on every upgrade.
  storage_class_tags = {
    for key, value in var.tags : key => value
    if key != "ForgeModuleRef"
  }
  storage_classes = var.migrate_arc_cluster ? [] : distinct([
    for runner in values(var.multi_runner_config) : {
      name = "${runner.runner_set_configs.namespace}-${runner.runner_config.volume_requests_storage_type}"
      type = runner.runner_config.volume_requests_storage_type
    }
  ])

  # Build the name and manifest from the same immutable specification. A real
  # storage setting change creates a new class instead of patching one that
  # Kubernetes does not allow Terraform to update in place.
  storage_class_manifests = {
    for storage_class in local.storage_classes : storage_class.name => {
      apiVersion  = "storage.k8s.io/v1"
      kind        = "StorageClass"
      provisioner = "kubernetes.io/aws-ebs"
      parameters = merge(
        {
          type      = storage_class.type
          fsType    = "ext4"
          encrypted = "true"
        },
        {
          for i, key in sort(keys(local.storage_class_tags)) :
          "tagSpecification_${i + 1}" => "${key}=${local.storage_class_tags[key]}"
        }
      )
      reclaimPolicy     = "Delete"
      volumeBindingMode = "WaitForFirstConsumer"
    }
  }
}

resource "kubernetes_manifest" "storage_class" {
  for_each = local.storage_class_manifests

  manifest = merge(each.value, {
    metadata = merge(
      {
        name = "${each.key}-${sha1(jsonencode(each.value))}"
      },
      contains(keys(var.tags), "ForgeModuleRef") ? {
        annotations = {
          "forge.cisco.com/module-ref" = var.tags["ForgeModuleRef"]
        }
      } : {}
    )
  })

  lifecycle {
    create_before_destroy = true
  }
}
