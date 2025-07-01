resource "null_resource" "apply_tigera_operator" {
  provisioner "local-exec" {
    command = "kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml"
  }

  depends_on = [
    null_resource.update_kubeconfig,
  ]
}

locals {
  dockerhub_user  = data.aws_secretsmanager_secret_version.secrets["dockerhub_user"].secret_string
  dockerhub_token = data.aws_secretsmanager_secret_version.secrets["dockerhub_token"].secret_string
  dockerhub_email = data.aws_secretsmanager_secret_version.secrets["dockerhub_email"].secret_string
  dockerhub_auth  = base64encode("${local.dockerhub_user}:${local.dockerhub_token}")
}

resource "kubernetes_secret" "calico_image_pull" {
  metadata {
    name      = "calico-regcred"
    namespace = "tigera-operator"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          "username" = local.dockerhub_user
          "password" = local.dockerhub_token
          "email"    = local.dockerhub_email
          "auth"     = local.dockerhub_auth
        }
      }
    })
  }

  depends_on = [
    null_resource.apply_tigera_operator,
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
  imagePullSecrets:
    - name: calico-regcred
EOF
  }

  depends_on = [
    null_resource.apply_tigera_operator,
    kubernetes_secret.calico_image_pull,
  ]
}
