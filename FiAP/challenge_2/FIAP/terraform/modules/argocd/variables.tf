variable "chart_version" {
  type        = string
  description = "Versão fixa do chart argo-cd (evita drift)."
  default     = "7.7.16"
}
