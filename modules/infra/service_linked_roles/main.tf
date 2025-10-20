resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
  tags             = local.all_security_tags
  tags_all         = local.all_security_tags
}
