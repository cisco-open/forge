resource "null_resource" "apply_tigera_operator" {
  provisioner "local-exec" {
    command = "kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml"
  }

  depends_on = [
    null_resource.update_kubeconfig,
  ]
}

locals {
  dockerhub_user  = data.aws_secretsmanager_secret_version.secrets["dockerhub_user"].secret_string
  dockerhub_token = data.aws_secretsmanager_secret_version.secrets["dockerhub_token"].secret_string
  dockerhub_email = data.aws_secretsmanager_secret_version.secrets["dockerhub_email"].secret_string
  # dockerhub_auth  = base64encode("${local.dockerhub_user}:${local.dockerhub_token}")
}

resource "null_resource" "create_or_update_calico_secret" {
  provisioner "local-exec" {
    command = <<EOF
kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} create secret docker-registry calico-regcred \
  --namespace=tigera-operator \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="${local.dockerhub_user}" \
  --docker-password="${local.dockerhub_token}" \
  --docker-email="${local.dockerhub_email}" \
  --dry-run=client -o yaml | kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
EOF
  }

  triggers = {
    dockerhub_user  = local.dockerhub_user
    dockerhub_token = sha256(local.dockerhub_token)
    dockerhub_email = local.dockerhub_email
  }

  depends_on = [
    null_resource.apply_tigera_operator,
  ]
}

resource "null_resource" "create_calico_installation" {
  provisioner "local-exec" {
    command = <<EOF
kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f - <<EOF
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
  imagePullSecrets:
    - name: calico-regcred
EOF
  }

  depends_on = [
    null_resource.apply_tigera_operator,
    null_resource.create_or_update_calico_secret,
  ]
}
