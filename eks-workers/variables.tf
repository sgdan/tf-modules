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
  default     = ["t3.small", "t3a.small"]
}

variable "worker_sg_id" {
  description = "ID of worker security group"
}

variable "cidrs" {
  description = "CIDR blocks to allow access to ALB"
  default     = []
}

variable "certificate_arn" {
  description = "ARN of certificate to configure on ALB"
}

variable "domain" {
  description = "Domain to access eks workers"
  default     = "example.com"
}

variable "prefix" {
  description = "Name to prefix to the domain"
  default     = "eks"
}
