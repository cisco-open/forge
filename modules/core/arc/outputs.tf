output "runners_map" {
  value = { for key, value in module.scale_sets : key => value }
}

output "subnet_cidr_blocks" {
  value = length(var.multi_runner_config) < 1 ? [] : [for s in values(data.aws_subnet.eks_subnets) : s.cidr_block]
}
