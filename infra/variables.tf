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
