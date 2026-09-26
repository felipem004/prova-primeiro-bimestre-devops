# =============================================================================
# modules/rds/outputs.tf: saídas do módulo de banco de dados
# -----------------------------------------------------------------------------
# Ver a tabela de interfaces no design.md, §6.3. Nenhuma saída expõe a
# senha (CA-06.2).
# =============================================================================

output "endereco" {
  description = "Hostname do banco (sem a porta). Usado pelo módulo ec2 como DB_HOST."
  # "address" é só o hostname. O atributo "endpoint" traz "hostname:porta",
  # o que quebraria a variável DB_HOST da API, que espera só o hostname.
  value = aws_db_instance.principal.address
}

output "porta" {
  description = "Porta do banco. Usada pelo módulo ec2 como DB_PORT."
  value       = aws_db_instance.principal.port
}
