output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

# Alias para compatibilidade com RDS no mesmo bloco privado
output "database_subnet_ids" {
  value = aws_subnet.private[*].id
}
