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

variable "db_user" {
  description = "Postgres user"
  default     = "concourse"
}

variable "db_address" {
  description = "Postgres db host address"
}

variable "db_pass" {
  description = "Postgres db password"
}
