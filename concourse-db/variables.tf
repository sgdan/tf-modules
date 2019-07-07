
variable "vpc_id" {
  description = "ID of VPC where database will be created"
}

variable "private_subnet_ids" {
  description = "IDS of private subnets for database"
}

variable "password" {
  description = "Initial password for Concourse database"
}
