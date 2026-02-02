module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.15.1"

  namespace    = "karpenter"
  cluster_name = var.cluster_name

  create_instance_profile = true

  tags = merge(local.all_security_tags, { "calico_dependency" = local._wait_for_calico })

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "null_resource" "karpenter" {
  depends_on = [module.eks]

  triggers = {
    chart_version      = "1.8.3"
    service_account    = module.karpenter.service_account
    cluster_name       = module.eks.cluster_name
    cluster_endpoint   = module.eks.cluster_endpoint
    interruption_queue = module.karpenter.queue_name
    kube_context       = "${var.cluster_name}-${var.aws_profile}-${var.aws_region}"
  }

  # --- CREATE / UPDATE ---
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
set -euxo pipefail

echo "PATH=$PATH"
command -v helm || { echo "helm not found"; exit 1; }
command -v kubectl || { echo "kubectl not found"; exit 1; }

# Ensure namespace exists
kubectl --context ${self.triggers.kube_context}  apply -f - <<EOF2
apiVersion: v1
kind: Namespace
metadata:
  name: karpenter
EOF2

helm --kube-context ${self.triggers.kube_context} upgrade \
  --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace karpenter \
  --version ${self.triggers.chart_version} \
  --set serviceAccount.name=${self.triggers.service_account} \
  --set dnsPolicy=Default \
  --set settings.clusterName=${self.triggers.cluster_name} \
  --set settings.clusterEndpoint=${self.triggers.cluster_endpoint} \
  --set settings.interruptionQueue=${self.triggers.interruption_queue} \
  --set 'tolerations[0].key'=CriticalAddonsOnly \
  --set 'tolerations[0].operator'=Exists \
  --set 'tolerations[1].key'=karpenter.sh/controller \
  --set 'tolerations[1].operator'=Exists \
  --set 'tolerations[1].effect'=NoSchedule \
  --set webhook.enabled=false
EOF
  }

  # --- DESTROY ---
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
set -euxo pipefail

echo "PATH=$PATH"
command -v helm || { echo "helm not found"; exit 1; }
command -v kubectl || { echo "kubectl not found"; exit 1; }

echo "Uninstalling Karpenter..."

# Try uninstall, but don't fail destroy if already gone
helm --kube-context ${self.triggers.kube_context} uninstall karpenter -n karpenter || true

# Optionally cleanup namespace (safe only if nothing else is inside)
kubectl --context ${self.triggers.kube_context} delete namespace karpenter --ignore-not-found=true
EOF
  }
}

locals {
  ec2_node_class_manifest = templatefile("${path.module}/templates/ec2_node_class.yaml.tpl", {
    ami_id                    = data.aws_ami.eks_default.image_id
    role_arn                  = module.karpenter.node_iam_role_arn
    subnet_ids                = var.subnet_ids
    primary_security_group_id = module.eks.cluster_primary_security_group_id
    security_group_id         = module.eks.cluster_security_group_id
    tags                      = local.all_security_tags
    disk_size                 = var.cluster_volume.size
    disk_type                 = var.cluster_volume.type
    disk_iops                 = var.cluster_volume.iops
    disk_throughput           = var.cluster_volume.throughput
  })

  node_pool_manifest = templatefile("${path.module}/templates/node_pool.yaml.tpl", {})
}

resource "null_resource" "apply_ec2_node_class" {
  provisioner "local-exec" {
    command = <<EOF
kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} patch ec2nodeclass karpenter --type='merge' -p '{"metadata":{"finalizers":[]}}' || true
kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} delete ec2nodeclass karpenter || true
echo "${local.ec2_node_class_manifest}" | kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
EOF
  }

  triggers = {
    ami_id                    = data.aws_ami.eks_default.image_id
    role_arn                  = module.karpenter.node_iam_role_arn
    primary_security_group_id = module.eks.cluster_primary_security_group_id
    security_group_id         = module.eks.cluster_security_group_id
    template_file_hash        = filesha256("${path.module}/templates/ec2_node_class.yaml.tpl")
  }

  depends_on = [
    null_resource.karpenter,
  ]
}

resource "null_resource" "apply_node_pool" {
  provisioner "local-exec" {
    command = <<EOF
echo "${local.node_pool_manifest}" | kubectl --context ${var.cluster_name}-${var.aws_profile}-${var.aws_region} apply -f -
EOF
  }

  triggers = {
    manifest_hash = sha256("${path.module}/templates/node_pool.yaml.tpl")
  }

  depends_on = [
    null_resource.apply_ec2_node_class
  ]
}
