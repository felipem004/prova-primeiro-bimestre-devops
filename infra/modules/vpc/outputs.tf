# =============================================================================
# modules/vpc/outputs.tf: saídas do módulo de rede
# -----------------------------------------------------------------------------
# Estas são as "respostas" do módulo, usadas pelos outros módulos através do
# main.tf da raiz (ex.: module.vpc.vpc_id). Ver a tabela de interfaces no
# design.md, §6.1.
# =============================================================================

output "vpc_id" {
  description = "ID da VPC. Usado pelo módulo security-group."
  value       = aws_vpc.principal.id
}

output "id_subrede_publica" {
  description = "ID da sub-rede pública. Usado pelo módulo ec2."
  value       = aws_subnet.publica.id
}

output "ids_subredes_privadas" {
  description = "IDs das sub-redes privadas, em AZs diferentes. Usado pelo módulo rds."
  # O "[*]" (splat) pega o atributo "id" de TODAS as cópias criadas com
  # count e devolve uma lista.
  value = aws_subnet.privada[*].id
}
