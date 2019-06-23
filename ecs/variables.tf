variable "name" {
  description = "Name of this ECS cluster"
  default     = "main"
}

variable "vpc_id" {
  description = "ID of VPC where cluster will be created"
}

variable "subnet_ids" {
  description = "IDs of subnets where nodes will be created"
}

variable "log_group" {
  description = "Name of CloudWatch log group to create"
  default     = "/ecs/tasks"
}
