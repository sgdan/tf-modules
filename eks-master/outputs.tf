output "cluster" {
  description = "The EKS cluster that was provisioned"
  value       = aws_eks_cluster.this
}

output "worker_sg_id" {
  description = "ID of worker security group for eks"
  value       = aws_security_group.workers.id
}
