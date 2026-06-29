# example/main.tf
# Config minima para provar o ciclo tofu + MiniStack antes de apontar para os
# stacks reais do Forge. Espelha a forma do data plane (fila, bucket, segredo).
terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Os endpoints/credenciais vem do ministack_override.tf (mesclado neste dir).
provider "aws" {
  region = "us-east-1"
}

resource "aws_sqs_queue" "events" {
  name = "forge-tf-smoke-events"
}

resource "aws_sqs_queue" "dlq" {
  name = "forge-tf-smoke-events-dlq"
}

resource "aws_s3_bucket" "logs" {
  bucket = "forge-tf-smoke-tenant-logs"
}

resource "aws_ssm_parameter" "secret" {
  name  = "/forge/tf-smoke/webhook-secret"
  type  = "SecureString"
  value = "not-a-real-secret"
}

output "queue_url" {
  value = aws_sqs_queue.events.id
}

output "bucket" {
  value = aws_s3_bucket.logs.bucket
}
