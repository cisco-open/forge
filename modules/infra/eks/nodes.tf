data "aws_ami" "eks_default" {
  most_recent = true
  owners      = var.cluster_ami_owners

  filter {
    name   = "name"
    values = var.cluster_ami_filter
  }
}
module "self_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"
  version = "21.1.0"

  name                = var.cluster_name
  cluster_name        = var.cluster_name
  kubernetes_version  = var.cluster_version
  cluster_endpoint    = module.eks.cluster_endpoint
  cluster_auth_base64 = module.eks.cluster_certificate_authority_data

  subnet_ids = var.subnet_ids

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = var.cluster_volume.size
        volume_type           = var.cluster_volume.type
        iops                  = var.cluster_volume.iops
        throughput            = var.cluster_volume.throughput
        encrypted             = true
        kms_key_id            = null
        delete_on_termination = true
      }
    }
  }

  iam_role_additional_policies = {
    "AmazonSSMManagedInstanceCore" = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  vpc_security_group_ids = [
    module.eks.cluster_primary_security_group_id,
    module.eks.cluster_security_group_id,
  ]

  ami_type = "AL2023_x86_64_STANDARD"
  ami_id   = data.aws_ami.eks_default.image_id

  user_data_template_path = "${path.module}/templates/node_config.yaml.tpl"

  cluster_service_cidr = module.eks.cluster_service_cidr

  min_size     = var.cluster_size.min_size
  max_size     = var.cluster_size.max_size
  desired_size = var.cluster_size.desired_size

  launch_template_name = var.cluster_name
  instance_type        = var.cluster_size.instance_type

  tags = merge(local.all_security_tags, { "calico_dependency" = local._wait_for_calico })

}
