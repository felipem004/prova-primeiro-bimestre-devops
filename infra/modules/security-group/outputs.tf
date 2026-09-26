# =============================================================================
# modules/security-group/outputs.tf: saídas do módulo de firewall
# -----------------------------------------------------------------------------
# Ver a tabela de interfaces no design.md, §6.2.
# =============================================================================

output "id_sg_ec2" {
  description = "ID do Security Group da EC2. Usado pelo módulo ec2."
  value       = aws_security_group.ec2.id
}

output "id_sg_rds" {
  description = "ID do Security Group do RDS. Usado pelo módulo rds."
  value       = aws_security_group.rds.id
}
