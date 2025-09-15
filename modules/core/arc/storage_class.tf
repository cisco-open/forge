locals {
  storage_classes = distinct([
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
      name = "${each.value.name}-${sha1(join(",", [for k in sort(keys(var.tags)) : "${k}=${var.tags[k]}"]))}"
    }
    provisioner = "kubernetes.io/aws-ebs"
    parameters = merge(
      {
        type      = each.value.type
        fsType    = "ext4"
        encrypted = "true"
      },
      {
        for i, k in keys(var.tags) : "tagSpecification_${i + 1}" => "${k}=${var.tags[k]}"
      }
    )
    reclaimPolicy     = "Delete"
    volumeBindingMode = "WaitForFirstConsumer"
  }
}
