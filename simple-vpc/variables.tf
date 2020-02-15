variable "vpc_cidr" {
  description = "Main cidr range for VPC"
  default     = "192.168.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Cidr ranges of private subnets"
  type        = list(string)
  default     = ["192.168.64.0/19", "192.168.96.0/19"]
}

variable "public_subnet_cidrs" {
  description = "Cidr ranges of public subnets"
  type        = list(string)
  default     = ["192.168.0.0/19", "192.168.32.0/19"]
}

variable "custom_vpc_tags" {
  description = "Additional tags to add to VPC"
  type        = map(string)
  default     = {}
}

variable "custom_private_tags" {
  description = "Additional tags to add to private subnets"
  type        = map(string)
  default     = {}
}
