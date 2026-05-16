variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "Security group primário do cluster EKS (vpc_config.cluster_security_group_id)."
}
