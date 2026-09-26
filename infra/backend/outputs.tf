# =============================================================================
# outputs.tf (backend): saídas deste projeto
# -----------------------------------------------------------------------------
# Os valores abaixo são usados para montar o arquivo infra/backend.hcl (T-05),
# que liga o projeto principal a este bucket e a esta tabela.
#
# Eles aparecem no terminal ao fim do "apply" e podem ser vistos de novo a
# qualquer momento com "terraform output". O nome do bucket contém o ID da
# conta: não cole essa saída em lugares públicos.
# =============================================================================

output "nome_bucket" {
  description = "Nome do bucket S3 que guarda o state do projeto principal."
  value       = aws_s3_bucket.state.id
}

output "nome_tabela_lock" {
  description = "Nome da tabela DynamoDB usada para o lock do state."
  value       = aws_dynamodb_table.lock.name
}

output "regiao" {
  description = "Região onde o bucket e a tabela foram criados."
  value       = var.aws_region
}
