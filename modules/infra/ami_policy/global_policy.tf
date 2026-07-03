# Always encrypt new EBS volumes (e.g. AMI images) by default. Packer is not
# able to override/disable this setting.
resource "aws_ebs_encryption_by_default" "gpol_encrypt_ebs" {
  #checkov:skip=CKV_AWS_106:AMI build helper leaves account EBS default encryption disabled until tenant accounts provide their own KMS key strategy.
  # We'll re-enable this when we have a custom KMS key prepared.
  enabled = false
}
