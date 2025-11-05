data "external" "s3_buckets" {
  program = [
    "${path.module}/scripts/list_buckets.sh",
    var.aws_profile,
    var.aws_region
  ]
}
locals {
  bucket_list = jsondecode(data.external.s3_buckets.result.buckets)
}

resource "aws_s3_bucket_notification" "logs" {
  for_each = { for b in local.bucket_list : b.name => b }
  bucket   = each.key

  queue {
    id            = "logs"
    queue_arn     = aws_sqs_queue.log_events_queue.arn
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:CompleteMultipartUpload"]
    filter_suffix = ".log"
  }

  queue {
    id            = "json"
    queue_arn     = aws_sqs_queue.log_events_queue.arn
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:CompleteMultipartUpload"]
    filter_suffix = ".json"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}
