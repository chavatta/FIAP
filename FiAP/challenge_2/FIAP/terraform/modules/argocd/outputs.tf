output "namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "helm_release_status" {
  value = helm_release.argocd.status
}
