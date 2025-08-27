locals {
  node_pool_manifest = templatefile("${path.module}/templates/node_pool.yaml.tpl", {
    tenant = var.controller_config.namespace
  })

  kubeconfig_path = "${path.cwd}/.kube/${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region}-${var.controller_config.namespace}.kubeconfig"
}

data "external" "update_kubeconfig" {
  program = ["bash", "-c", <<EOT
    mkdir -p "$(dirname '${local.kubeconfig_path}')"

    aws eks update-kubeconfig \
      --region '${var.aws_region}' \
      --name '${var.eks_cluster_name}' \
      --alias '${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region}' \
      --profile '${var.aws_profile}' \
      --kubeconfig '${local.kubeconfig_path}' >/dev/null 2>&1

    echo '{"updated":"true"}'
  EOT
  ]
}

data "external" "karpenter_ec2nodeclass" {
  depends_on = [data.external.update_kubeconfig]

  program = [
    "bash",
    "-c",
    <<-EOT
      kubectl --kubeconfig '${local.kubeconfig_path}' --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} get ec2nodeclasses.karpenter.k8s.aws karpenter -o yaml \
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
export KUBECONFIG='${local.kubeconfig_path}'
# Delete existing EC2NodeClass if it exists (needed to update immutable fields)
while kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} get ec2nodeclasses.karpenter.k8s.aws "karpenter-${var.controller_config.namespace}" >/dev/null 2>&1; do
  sleep 1
  kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} patch ec2nodeclasses.karpenter.k8s.aws "karpenter-${var.controller_config.namespace}" --type=merge -p '{"metadata":{"finalizers":[]}}' || true
  kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} delete ec2nodeclasses.karpenter.k8s.aws "karpenter-${var.controller_config.namespace}" --ignore-not-found || true
done

# Apply the new EC2NodeClass manifest only if not migrating
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
    data.external.update_kubeconfig,
  ]
}

resource "null_resource" "apply_node_pool" {
  provisioner "local-exec" {
    command = <<EOF
export KUBECONFIG='${local.kubeconfig_path}'
if [ "${var.migrate_arc_cluster}" = "false" ]; then
  echo "${local.node_pool_manifest}" \
    | kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
else
  # Force delete NodePool resources if migration is active
  kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} delete nodepools.karpenter.sh "karpenter-${var.controller_config.namespace}" --ignore-not-found || true
fi
EOF
  }

  triggers = {
    manifest_hash       = sha256("${path.module}/templates/node_pool.yaml.tpl")
    migrate_arc_cluster = var.migrate_arc_cluster
  }

  depends_on = [
    null_resource.apply_ec2_node_class,
    data.external.update_kubeconfig,
  ]
}
