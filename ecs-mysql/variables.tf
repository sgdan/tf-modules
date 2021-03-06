variable "ecs_cluster" {
  description = "Name of the ECS cluster to run on"
  default     = "main"
}

variable "vpc_id" {
  description = "ID of VPC"
}

variable "private_namespace_id" {
  description = "ID of service discovery namespace"
}
