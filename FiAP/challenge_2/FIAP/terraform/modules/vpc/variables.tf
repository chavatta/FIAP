variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "Usado nas tags exigidas pelo EKS para subnets."
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = [] # se vazio, derivar de aws_region no root — aqui passamos do root
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}
