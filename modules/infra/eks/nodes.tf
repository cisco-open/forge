module "self_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"
  version = "20.35.0"

  name                = var.cluster_name
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  cluster_endpoint    = module.eks.cluster_endpoint
  cluster_auth_base64 = module.eks.cluster_certificate_authority_data

  subnet_ids = var.subnet_ids

  block_device_mappings = {
    xvda = {
      device_name = "/dev/sda1"
      ebs = {
        volume_size           = 200
        volume_type           = "gp3"
        iops                  = 10000
        throughput            = 500
        encrypted             = true
        kms_key_id            = null
        delete_on_termination = true
      }
    }
  }

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  vpc_security_group_ids = [
    module.eks.cluster_primary_security_group_id,
    module.eks.cluster_security_group_id,
  ]

  ami_type = "AL2_x86_64"
  ami_id   = data.aws_ami.eks_default.image_id

  bootstrap_extra_args = <<-EOT
    --use-max-pods false
    --max-pods 100
  EOT

  cluster_service_cidr = module.eks.cluster_service_cidr

  min_size     = var.cluster_size.min_size
  max_size     = var.cluster_size.max_size
  desired_size = var.cluster_size.desired_size

  launch_template_name = var.cluster_name
  instance_type        = var.cluster_size.instance_type

  tags = local.all_security_tags

  depends_on = [
    time_sleep.wait_300_seconds,
  ]
}
