# =============================================================================
# variables.tf: entradas do projeto principal
# -----------------------------------------------------------------------------
# As variáveis entram junto com os módulos que as usam, até a T-10
# (design §7). Os valores reais ficam no terraform.tfvars (local, ignorado
# pelo Git); o modelo é o terraform.tfvars.example.
# =============================================================================

variable "aws_region" {
  description = "Região da AWS onde a infraestrutura será criada (padrão do Learner Lab)."
  type        = string
  default     = "us-east-1"
}

# As validações de cidr_ssh e cidr_http ficam no módulo security-group, que
# é onde as regras de firewall são criadas. Um valor inválido informado aqui
# é barrado lá, já no "plan".
variable "cidr_ssh" {
  description = "Seu IP público com /32 (ex.: 200.100.50.25/32), único autorizado a acessar a EC2 por SSH."
  type        = string
}

variable "cidr_http" {
  description = "Faixa de IPs autorizada a acessar a API na porta 80. Padrão: a internet toda."
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_senha" {
  description = "Senha do usuário principal do RDS. Mínimo de 16 caracteres; sem /, @, aspas duplas ou espaços."
  type        = string
  sensitive   = true # esconde o valor no plan/apply (mas ele fica no state)

  # Validação da senha (design §7). As mensagens de erro NÃO mostram o
  # valor, porque a variável é sensitive.
  #
  # - length(...) entre 16 e 128: 16 é o nosso mínimo de segurança (a AWS
  #   aceita 8); 128 é o máximo que o RDS PostgreSQL aceita.
  # - regex("[/@\" ]", ...): procura qualquer um dos caracteres que o RDS
  #   PROÍBE na senha principal: barra, arroba, aspas duplas e espaço. O
  #   "!can(...)" significa "NÃO encontrou nenhum".
  validation {
    condition     = length(var.db_senha) >= 16 && length(var.db_senha) <= 128
    error_message = "db_senha precisa ter entre 16 e 128 caracteres."
  }

  validation {
    condition     = !can(regex("[/@\" ]", var.db_senha))
    error_message = "db_senha não pode conter /, @, aspas duplas (\") nem espaços (restrição do RDS)."
  }
}
