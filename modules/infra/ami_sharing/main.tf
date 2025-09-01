# Fetch all matching AMIs
data "aws_ami" "selected" {
  for_each    = toset(var.ami_name_filters)
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [each.value]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  selected_ami_ids = distinct([for _, d in data.aws_ami.selected : d.id])

  ami_account_pairs = flatten([
    for ami in local.selected_ami_ids : [
      for account in var.account_ids : {
        ami_id  = ami
        account = account
      }
    ]
  ])
}

resource "aws_ami_launch_permission" "share_amis" {
  for_each = { for pair in local.ami_account_pairs : "${pair.ami_id}-${pair.account}" => pair }

  image_id   = each.value.ami_id
  account_id = each.value.account
}
