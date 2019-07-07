
variable "vpc_id" {
  description = "ID of VPC where cluster will be created"
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for load balancer"
}

variable "private_subnet_ids" {
  description = "IDS of private subnets for cluster nodes"
}

variable "name" {
  description = "Name of this ECS cluster"
  default     = "main"
}

variable "internet_whitelist" {
  description = "Addresses to allow from the internet"
}

variable "domain" {
  description = "Domain to create DNS entry in"
}

variable "certificate_arn" {
  description = "ARN of certificate to use on ALB"
}
