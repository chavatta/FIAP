output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  value = { for k, m in module.ecr : k => m.repository_url }
}

output "rds_endpoints" {
  value = { for k, m in module.rds : k => m.db_endpoint }
}

output "redis_primary_endpoint" {
  value = module.elasticache.primary_endpoint
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "argocd_server_command" {
  description = "Após instalar, use port-forward para a UI do ArgoCD."
  value       = var.enable_argocd ? "kubectl port-forward svc/argocd-server -n argocd 8080:443" : "ArgoCD desabilitado"
}
