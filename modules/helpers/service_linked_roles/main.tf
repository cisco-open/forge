resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
  tags             = local.all_security_tags
  tags_all         = local.all_security_tags
}

resource "aws_iam_service_linked_role" "license_manager" {
  aws_service_name = "license-manager.amazonaws.com"
  tags             = local.all_security_tags
  tags_all         = local.all_security_tags
}
