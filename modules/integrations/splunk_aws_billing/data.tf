data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  primary_billing_view_arn = "arn:${data.aws_partition.current.partition}:billing::${data.aws_caller_identity.current.account_id}:billingview/primary"
}
