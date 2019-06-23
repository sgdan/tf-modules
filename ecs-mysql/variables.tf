variable "ecs_cluster" {
  description = "Name of the ECS cluster to run on"
  default     = "main"
}

variable "log_group" {
  description = "Name of CloudWatch log group to use"
  default     = "/ecs/tasks"
}
