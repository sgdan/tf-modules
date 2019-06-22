output "worker_sg_id" {
  description = "ID of worker security group for eks"
  value       = aws_security_group.workers.id
}
