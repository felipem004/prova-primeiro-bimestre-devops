# =============================================================================
# variables.tf: entradas do projeto principal
# -----------------------------------------------------------------------------
# Por enquanto, só a região, usada pelo provider (T-05). As demais variáveis
# (cidr_ssh, cidr_http, url_repositorio, db_senha...) entram junto com os
# módulos que as usam, até a T-10 (design §7).
# =============================================================================

variable "aws_region" {
  description = "Região da AWS onde a infraestrutura será criada (padrão do Learner Lab)."
  type        = string
  default     = "us-east-1"
}
