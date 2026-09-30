locals {
  # ForgeModuleRef changes on every Forge release. Keeping it in the EBS tag
  # parameters makes the immutable StorageClass change on every upgrade.
  storage_class_tags = {
    for key, value in var.tags : key => value
    if key != "ForgeModuleRef"
  }
  storage_class_tag_hash = sha1(join(",", [
    for key in sort(keys(local.storage_class_tags)) : "${key}=${local.storage_class_tags[key]}"
  ]))

  storage_classes = var.migrate_arc_cluster ? [] : distinct([
    for runner in values(var.multi_runner_config) : {
      name = "${runner.runner_set_configs.namespace}-${runner.runner_config.volume_requests_storage_type}"
      type = runner.runner_config.volume_requests_storage_type
    }
  ])
}

resource "kubernetes_manifest" "storage_class" {

  for_each = { for sc in local.storage_classes : sc.name => sc }

  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "${each.value.name}-${local.storage_class_tag_hash}"
    }
    provisioner = "kubernetes.io/aws-ebs"
    parameters = merge(
      {
        type      = each.value.type
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

  lifecycle {
    create_before_destroy = true
  }
}
