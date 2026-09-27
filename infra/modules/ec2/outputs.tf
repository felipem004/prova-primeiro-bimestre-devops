# =============================================================================
# modules/ec2/outputs.tf: saídas do módulo do servidor da API
# -----------------------------------------------------------------------------
# Ver a tabela de interfaces no design.md, §6.4.
# =============================================================================

output "ip_publico" {
  description = "IP público da EC2. Muda se a instância for parada e ligada de novo."
  value       = aws_instance.api.public_ip
}

output "id_instancia" {
  description = "ID da instância EC2 (útil para pará-la ou ligá-la pelo AWS CLI)."
  value       = aws_instance.api.id
}
