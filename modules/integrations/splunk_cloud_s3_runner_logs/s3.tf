data "external" "s3_buckets" {
  program = [
    "${path.module}/scripts/list_buckets.sh",
    var.aws_profile
  ]
}
locals {
  bucket_list = jsondecode(data.external.s3_buckets.result.buckets)
}

resource "aws_s3_bucket_notification" "logs" {
  # for_each must be a map or set of strings; convert list of objects to map keyed by bucket name
  for_each = { for b in local.bucket_list : b.name => b }
  bucket   = each.key
  provider = aws.by_region[each.value.region]

  queue {
    queue_arn     = aws_sqs_queue.log_events_queue.arn
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:CompleteMultipartUpload"]
    filter_suffix = ".log"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

resource "aws_s3_bucket_notification" "json" {
  for_each = { for b in local.bucket_list : b.name => b }
  bucket   = each.key
  provider = aws.by_region[each.value.region]

  queue {
    queue_arn     = aws_sqs_queue.log_events_queue.arn
    events        = ["s3:ObjectCreated:Put", "s3:ObjectCreated:CompleteMultipartUpload"]
    filter_suffix = ".json"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}
