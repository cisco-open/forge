output "runners_map" {
  value = { for key, value in module.rs : key => value }
}

output "subnet_cidr_blocks" {
  value = { for id, subnet in data.aws_subnet.eks_subnets : id => subnet.cidr_block }
}
