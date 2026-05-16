variable "name_prefix" {
  type = string
}

variable "queue_name" {
  type = string
}

variable "message_retention_seconds" {
  type    = number
  default = 345600
}

variable "receive_wait_time_seconds" {
  type    = number
  default = 10
}
