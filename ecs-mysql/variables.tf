variable "ecs_cluster" {
  description = "Name of the ECS cluster to run on"
  default     = "main"
}

variable "log_group" {
  description = "Name of CloudWatch log group to use"
  default     = "/ecs/tasks"
}

variable "vpc_id" {
  description = "ID of VPC"
}

variable "private_namespace_id" {
  description = "ID of service discovery namespace"
}
