resource "null_resource" "patch_calico_installation" {
  depends_on = [null_resource.wait_for_cluster]
  provisioner "local-exec" {
    command = <<EOF
      set -eu

      kube_context="${var.cluster_name}-${var.aws_profile}-${var.aws_region}"
      max_attempts=30
      retry_interval_seconds=5
      attempt=1

      # EKS access policy associations are eventually consistent. Wait until
      # the cluster-admin permissions required by the bootstrap are effective.
      while ! kubectl --context "$kube_context" auth can-i patch customresourcedefinitions.apiextensions.k8s.io --quiet || \
        ! kubectl --context "$kube_context" auth can-i delete daemonsets.apps --namespace kube-system --quiet; do
        if [ "$attempt" -ge "$max_attempts" ]; then
          echo "Timed out waiting for EKS cluster-admin access after $max_attempts attempts." >&2
          exit 1
        fi

        echo "Waiting for EKS cluster-admin access (attempt $attempt/$max_attempts)..."
        sleep "$retry_interval_seconds"
        attempt=$((attempt + 1))
      done

      kubectl --context "$kube_context" delete daemonset -n kube-system aws-node --ignore-not-found=true
      kubectl --context "$kube_context" apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/operator-crds.yaml --server-side
      kubectl --context "$kube_context" wait --for=condition=Established --timeout=60s customresourcedefinition/installations.operator.tigera.io
      kubectl --context "$kube_context" apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/tigera-operator.yaml --server-side

      kubectl --context "$kube_context" apply -f - <<EOT
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
