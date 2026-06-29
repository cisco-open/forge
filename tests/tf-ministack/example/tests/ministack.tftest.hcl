# example/tests/ministack.tftest.hcl
# Roda com:  USE_MINISTACK=true tofu test   (MiniStack precisa estar up)
# Aplica de verdade no MiniStack e checa os recursos; o tofu destroi no fim.

run "apply_no_ministack" {
  command = apply

  assert {
    condition     = aws_sqs_queue.events.name == "forge-tf-smoke-events"
    error_message = "nome da fila SQS divergente"
  }

  assert {
    condition     = aws_s3_bucket.logs.bucket == "forge-tf-smoke-tenant-logs"
    error_message = "nome do bucket S3 divergente"
  }

  assert {
    condition     = aws_ssm_parameter.secret.type == "SecureString"
    error_message = "parametro SSM deveria ser SecureString"
  }
}
