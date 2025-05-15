resource "null_resource" "apply_tigera_operator" {
  provisioner "local-exec" {
    command = "kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml"
  }

  depends_on = [
    null_resource.update_kubeconfig,
  ]
}

resource "null_resource" "create_calico_installation" {
  provisioner "local-exec" {
    command = <<EOF
kubectl create -f - <<EOF2
kind: Installation
apiVersion: operator.tigera.io/v1
metadata:
  name: default
spec:
  kubernetesProvider: EKS
  cni:
    type: Calico
  calicoNetwork:
    bgp: Disabled
EOF2
EOF
  }

  depends_on = [
    null_resource.apply_tigera_operator,
  ]
}
