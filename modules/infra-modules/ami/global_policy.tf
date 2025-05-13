# Always encrypt new EBS volumes (e.g. AMI images) by default. Packer is not
# able to override/disable this setting.
resource "aws_ebs_encryption_by_default" "gpol_encrypt_ebs" {
  # We'll re-enable this when we have a custom KMS key prepared.
  enabled = false
}
