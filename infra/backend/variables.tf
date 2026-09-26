# =============================================================================
# variables.tf (backend): entradas deste projeto
# -----------------------------------------------------------------------------
# Todas as variáveis têm valor padrão, então este projeto roda sem nenhum
# arquivo .tfvars. Toda variável tem "description" (CA-Q.3): ela aparece na
# documentação e quando o Terraform pede um valor no terminal.
# =============================================================================

variable "aws_region" {
  description = "Região da AWS onde o bucket e a tabela serão criados (padrão do Learner Lab)."
  type        = string
  default     = "us-east-1"
}

variable "nome_projeto" {
  description = "Prefixo usado nos nomes dos recursos e na tag Projeto."
  type        = string
  default     = "api-reservas"

  # Nomes de bucket S3 só aceitam letras minúsculas, números e hífens. Esta
  # validação barra um valor inválido já no "plan", com uma mensagem clara,
  # em vez de deixar a AWS recusar o nome no meio do "apply".
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nome_projeto))
    error_message = "Use apenas letras minúsculas, números e hífens."
  }
}
