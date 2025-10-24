output "dynamodb_policy_arn" {
  description = "ARN of the IAM policy granting DynamoDB lock table CRUD access."
  value       = aws_iam_policy.dynamodb_policy.arn
}
