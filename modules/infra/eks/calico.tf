resource "null_resource" "patch_calico_installation" {
  depends_on = [null_resource.wait_for_cluster]
  provisioner "local-exec" {
    command = <<EOF
      kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} delete daemonset -n kube-system aws-node || true
      kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml --server-side
      kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml --server-side

      kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f - <<EOT
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  registry: quay.io/
  imagePath: calico
  kubernetesProvider: EKS
  cni:
    type: Calico
  calicoNetwork:
    bgp: Disabled
EOT
EOF
  }
}

locals {
  _wait_for_calico = null_resource.patch_calico_installation.id
}
