# Fetch all matching AMIs
data "aws_ami_ids" "ami_filter" {
  owners = ["self"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

# Create all AMI-account pairs
locals {
  ami_account_pairs = flatten([
    for ami in data.aws_ami_ids.ami_filter.ids : [
      for account in var.account_ids : {
        ami_id  = ami
        account = account
      }
    ]
  ])
}

# Share AMIs with accounts
resource "aws_ami_launch_permission" "share_amis" {
  for_each = { for pair in local.ami_account_pairs : "${pair.ami_id}-${pair.account}" => pair }

  image_id   = each.value.ami_id
  account_id = each.value.account
}
