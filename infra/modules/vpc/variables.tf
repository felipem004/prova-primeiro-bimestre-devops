# =============================================================================
# modules/vpc/variables.tf: entradas do módulo de rede
# -----------------------------------------------------------------------------
# Um MÓDULO é como uma função: recebe entradas (variáveis), cria recursos e
# devolve saídas (outputs). Quem chama o módulo (o main.tf da raiz) só
# precisa conhecer essa "interface", não os detalhes de dentro.
# =============================================================================

variable "nome" {
  description = "Prefixo usado na tag Name dos recursos de rede (ex.: api-reservas)."
  type        = string
}

variable "cidr_vpc" {
  description = "Faixa de IPs da VPC, em notação CIDR."
  type        = string
  default     = "10.0.0.0/16" # 65.536 endereços: 10.0.0.0 a 10.0.255.255

  # cidrhost() calcula um IP dentro da faixa e falha se o CIDR for inválido.
  # O can() transforma essa falha em "false", o que reprova a validação com
  # uma mensagem clara.
  validation {
    condition     = can(cidrhost(var.cidr_vpc, 0))
    error_message = "cidr_vpc precisa ser um CIDR válido, ex.: 10.0.0.0/16."
  }
}

variable "cidr_subrede_publica" {
  description = "Faixa de IPs da sub-rede pública (onde fica a EC2). Precisa estar dentro de cidr_vpc."
  type        = string
  default     = "10.0.1.0/24" # 256 endereços (a AWS reserva 5 em cada sub-rede)
}

variable "cidrs_subredes_privadas" {
  description = "Faixas de IPs das sub-redes privadas (onde fica o RDS), uma por zona de disponibilidade."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  # O DB subnet group do RDS exige sub-redes em pelo menos 2 zonas de
  # disponibilidade (CA-02.3). Barrar aqui evita descobrir o problema só na
  # hora de criar o banco.
  validation {
    condition     = length(var.cidrs_subredes_privadas) >= 2
    error_message = "Informe pelo menos 2 sub-redes privadas (exigência do RDS)."
  }
}
