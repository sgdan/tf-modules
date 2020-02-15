variable "vpc_id" {
  description = "ID of VPC where test instance will be created"
}

variable "subnet_id" {
  description = "ID of subnet where instance will be created"
}

variable "public_key" {
  description = "Public key to use when connecting via SSH"
}

variable "domain" {
  description = "Domain to access the instance public IP"
  default     = "example.com"
}

variable "prefix" {
  description = "Name to prefix to the domain"
  default     = "desktop"
}

variable "internal_prefix" {
  description = "DNS prefix to return private ip for tunnel"
  default     = "internal"
}
