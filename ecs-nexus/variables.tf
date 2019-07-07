variable "ecs_cluster" {
  description = "Name of the ECS cluster to run on"
  default     = "main"
}

variable "vpc_id" {
  description = "ID of VPC"
}

variable "domain" {
  description = "Domain where this service will be deplyed e.g. example.com"
}
