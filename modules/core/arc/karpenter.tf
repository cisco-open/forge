locals {
  node_pool_manifest = templatefile("${path.module}/templates/node_pool.yaml.tpl", {
    tenant = var.controller_config.namespace
  })
}

resource "null_resource" "update_kubeconfig" {
  # Use triggers to always run the provisioner
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig \
        --region ${var.aws_region} \
        --name ${var.eks_cluster_name} \
        --alias ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} \
        --profile ${var.aws_profile}
    EOT
  }
}

data "external" "karpenter_ec2nodeclass" {
  depends_on = [null_resource.update_kubeconfig]

  program = [
    "bash",
    "-c",
    <<-EOT
      kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} get ec2nodeclasses.karpenter.k8s.aws karpenter -o yaml \
      | yq eval '
          del(
            .metadata.creationTimestamp,
            .metadata.generation,
            .metadata.resourceVersion,
            .metadata.uid,
            .metadata.managedFields,
            .status,
            .metadata.annotations,
            .metadata.finalizers,
            .spec.metadataOptions
          )
        ' - \
      | yq eval -o=json - \
      | jq --argjson newtags '${jsonencode(var.tags)}' --arg newname "karpenter-${var.controller_config.namespace}" '
          .spec.tags *= $newtags
          | .metadata.name = $newname
        ' \
      | jq -c '.' | jq -Rs '{ data: . }'
    EOT
  ]
}


resource "null_resource" "apply_ec2_node_class" {
  provisioner "local-exec" {
    command = <<EOF
kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} patch ec2nodeclass "karpenter-${var.controller_config.namespace}" --type='merge' -p '{"metadata":{"finalizers":[]}}' || true
kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} delete ec2nodeclass "karpenter-${var.controller_config.namespace}" || true

if [ "${var.migrate_arc_cluster}" = "false" ]; then
  echo '${data.external.karpenter_ec2nodeclass.result.data}' \
    | yq eval -P - \
    | kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
fi
EOF
  }

  triggers = {
    ec2nodeclass        = data.external.karpenter_ec2nodeclass.result.data
    migrate_arc_cluster = var.migrate_arc_cluster
  }

  depends_on = [
    null_resource.update_kubeconfig,
  ]
}

resource "null_resource" "apply_node_pool" {
  provisioner "local-exec" {
    command = <<EOF
if [ "${var.migrate_arc_cluster}" = "false" ]; then
  echo "${local.node_pool_manifest}" | kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
else
  kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} delete nodepools "karpenter-${var.controller_config.namespace}" || true
fi
EOF
  }

  triggers = {
    manifest_hash       = sha256("${path.module}/templates/node_pool.yaml.tpl")
    migrate_arc_cluster = var.migrate_arc_cluster
  }

  depends_on = [
    null_resource.apply_ec2_node_class,
    null_resource.update_kubeconfig,
  ]
}
