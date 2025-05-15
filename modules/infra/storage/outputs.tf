output "s3_short_term_settings" {
  value = {
    "path"   = "${aws_s3_bucket.s3_short_term.id}/cicd_artifacts"
    "arn"    = aws_s3_bucket.s3_short_term.arn
    "suffix" = "/cicd_artifacts"
  }
  description = "Path to use for short-term storage of artifacts in S3."
}

output "s3_long_term_settings" {
  value = {
    "path"   = "${aws_s3_bucket.s3_long_term.id}/cicd_artifacts"
    "arn"    = aws_s3_bucket.s3_long_term.arn
    "suffix" = "/cicd_artifacts"
  }
  description = "Path to use for long-term storage of artifacts in S3."
}
