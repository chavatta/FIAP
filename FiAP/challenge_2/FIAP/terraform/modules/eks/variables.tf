variable "name_prefix" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "use_lab_role" {
  type = bool
}

variable "lab_role_name" {
  type = string
}

variable "cluster_role_arn" {
  type    = string
  default = ""
}

variable "node_role_arn" {
  type    = string
  default = ""
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_desired_size" {
  type = number
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Restrinja ao seu IP em produção."
  default     = ["0.0.0.0/0"]
}
