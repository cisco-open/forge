output "repository_policy_count" {
  value = length(aws_ecr_repository_policy.repository_policy)
}

output "repository_policy_names" {
  value = sort([
    for policy in aws_ecr_repository_policy.repository_policy : policy.repository
  ])
}
