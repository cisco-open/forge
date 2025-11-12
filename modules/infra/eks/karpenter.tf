module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.8.0"

  namespace    = "karpenter"
  cluster_name = var.cluster_name

  create_node_iam_role    = true
  create_instance_profile = true
  create_access_entry     = true

  tags = merge(local.all_security_tags, { "calico_dependency" = local._wait_for_calico })

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  create_pod_identity_association = true

}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.6.1"
  wait             = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: karpenter.sh/controller
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
    EOT
  ]
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
    helm_release.karpenter,
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
