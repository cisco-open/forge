# Create the actual ECR registries (one per image type).
resource "aws_ecr_repository" "ops_container_repository" {
  for_each = {
    for key, val in var.repositories : val.repo => val
  }
  name                 = each.value.repo
  image_tag_mutability = each.value.mutability

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }
  tags_all = local.all_security_tags
  tags     = local.all_security_tags
}

# Policies for our ECR instances.
# 1. Untagged images are automatically purged after 28 days.
# 2. Tagged images older than 180 days are purged.
# This boils down to the "pets versus cattle" analogy. This is a cloud
# platform, not a physical appliance. There are no "gold" images we use long
# term, as we're required to update artifacts at least once every 21 days or
# we're out of compliance with our internal security SLAs. Furthermore, there
# should **not** be some special, esoteric, un-documented practise on creating
# containers (even the first-round "bootstrap" variants). All artifacts should
# be equally valuable (and equally ready-to-discard when older than 21 days).
resource "aws_ecr_lifecycle_policy" "ops_cleanup_policy" {
  for_each = {
    for key, val in var.repositories : val.repo => val
  }
  repository = aws_ecr_repository.ops_container_repository[each.key].name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 28 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 28
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Expire tagged images with 'v' prefix after 180 days",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": [
          "v"
        ],
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 180
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Expire pre-release images after 2 days",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": [
          "*-pre-*"
        ],
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 2
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}
