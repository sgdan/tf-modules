output "worker_role_arn" {
  description = "IAM role ARN of worker instances"
  value       = aws_iam_role.this.arn
}
