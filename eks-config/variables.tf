variable "name" {
  description = "Name of eks cluster to configure"
  default     = "main"
}

variable "worker_role_arn" {
  description = "ARN of worker role for k8s auth role mapping"
}
