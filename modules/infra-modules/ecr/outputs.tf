output "ops_container_repository_names" {
  value = [for registry in aws_ecr_repository.ops_container_repository : registry.name]
}
