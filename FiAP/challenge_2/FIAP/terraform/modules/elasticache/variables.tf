variable "name_prefix" {
  type = string
}

variable "node_type" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "redis_security_group_id" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "7.0"
}

variable "num_cache_nodes" {
  type    = number
  default = 1
}
