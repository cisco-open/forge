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

resource "null_resource" "apply_node_pool" {
  provisioner "local-exec" {
    command = <<EOF
echo "${local.node_pool_manifest}" | kubectl --context ${var.eks_cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
EOF
  }

  triggers = {
    manifest_hash = sha256("${path.module}/templates/node_pool.yaml.tpl")
  }

  depends_on = [
    null_resource.update_kubeconfig,
  ]
}
