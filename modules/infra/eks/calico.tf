resource "null_resource" "patch_calico_installation" {
  provisioner "local-exec" {
    command = <<EOF
      kubectl --context ${data.external.update_kubeconfig.result.kubeconfig_alias} delete daemonset -n kube-system aws-node || true
      kubectl --context ${data.external.update_kubeconfig.result.kubeconfig_alias} apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml --server-side
      kubectl --context ${data.external.update_kubeconfig.result.kubeconfig_alias} apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml --server-side

      kubectl --context ${data.external.update_kubeconfig.result.kubeconfig_alias} apply -f - <<EOT
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
