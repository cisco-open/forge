output "runners_map" {
  value = { for key, value in module.scale_sets : key => value }
}

output "subnet_cidr_blocks" {
  value = length(var.multi_runner_config) < 1 ? {} : { for id, subnet in data.aws_subnet.eks_subnets : id => subnet.cidr_block }
}
