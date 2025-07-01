
resource "kubernetes_secret" "calico_image_pull" {
  metadata {
    name      = "calico-regcred"
    namespace = "tigera-operator"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = base64encode(jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = data.aws_secretsmanager_secret_version.secrets["dockerhub_user"].secret_string
          password = data.aws_secretsmanager_secret_version.secrets["dockerhub_token"].secret_string
          email    = data.aws_secretsmanager_secret_version.secrets["dockerhub_email"].secret_string
          auth     = base64encode("${data.aws_secretsmanager_secret_version.secrets["dockerhub_user"].secret_string}:${data.aws_secretsmanager_secret_version.secrets["dockerhub_token"].secret_string}")
        }
      }
    }))
  }
}

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
  imagePullSecrets:
    - name: calico-regcred
EOF
  }

  depends_on = [
    kubernetes_secret.calico_image_pull,
    null_resource.apply_tigera_operator,
  ]
}
