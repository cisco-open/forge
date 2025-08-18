resource "helm_release" "calico" {
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  version          = "v3.30.2"
  namespace        = "tigera-operator"
  create_namespace = true
  wait             = false

  set = [
    {
      name  = "installation.kubernetesProvider"
      value = "EKS"
    },
    {
      name  = "installation.kubeletVolumePluginPath"
      value = "/var/lib/kubelet"
    },
  ]

  depends_on = [null_resource.delete_daemonset]
}

resource "null_resource" "patch_calico_installation" {
  provisioner "local-exec" {
    command = <<EOF
kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} patch installation default \
  --namespace tigera-operator \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/cni", "value":{"type":"Calico"}},
    {"op": "replace", "path": "/spec/calicoNetwork", "value":{"bgp":"Disabled"}},
  ]'
EOF
  }

  depends_on = [
    helm_release.calico,
  ]
}
