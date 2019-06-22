variable "vpc_id" {
  description = "VPC with EKS cluster"
}

variable "name" {
  description = "Name of eks cluster to connect workers to"
  default     = "main"
}

variable "instance_types" {
  description = "Spot instance types for workers, should be at least 2"
  type        = list(string)
  default     = ["t2.small", "t3.small"]
}

variable "worker_sg_id" {
  description = "ID of worker security group"
}