# These are used to enforce lifecycle rules on AMI images, so that old images
# are automatically purged.
resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "dlm-lifecycle-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "dlm.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

# For defining the permissions needed for this lifecycle to take effect.
resource "aws_iam_role_policy" "dlm_lifecycle" {
  name = "dlm-lifecycle-policy"
  role = aws_iam_role.dlm_lifecycle_role.id

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateSnapshot",
            "ec2:CreateSnapshots",
            "ec2:DeleteSnapshot",
            "ec2:DescribeInstances",
            "ec2:DescribeVolumes",
            "ec2:DescribeSnapshots"
         ],
         "Resource": "*"
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateTags"
         ],
         "Resource": "arn:aws:ec2:*::snapshot/*"
      }
   ]
}
EOF

}

# Retain roughly 2 months of old AMI images.
resource "aws_dlm_lifecycle_policy" "dlm_lifecycle" {
  description        = "AMI DLM lifecycle policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "2 months of daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:45"]
      }

      # Number of days for which we retain images.
      retain_rule {
        count = 60
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        IsLifeCycled    = "yes"
      }

      copy_tags = false
    }

    target_tags = {
      role = "github-runner"
    }
  }

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}
