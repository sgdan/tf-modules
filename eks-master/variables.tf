variable "vpc_id" {
  description = "VPC for EKS cluster"
}

variable "name" {
  description = "Name of eks cluster to create"
  default     = "main"
}
