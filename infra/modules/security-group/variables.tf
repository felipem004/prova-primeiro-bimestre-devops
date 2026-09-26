# =============================================================================
# modules/security-group/variables.tf: entradas do módulo de firewall
# =============================================================================

variable "nome" {
  description = "Prefixo usado no nome e na tag Name dos Security Groups."
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde os Security Groups serão criados (output do módulo vpc)."
  type        = string
}

variable "cidr_ssh" {
  description = "Faixa de IPs autorizada a acessar a EC2 por SSH (porta 22). Use o seu IP público com /32."
  type        = string
  # SEM valor padrão, de propósito: quem usa o módulo é OBRIGADO a informar,
  # e não existe um padrão perigoso (como 0.0.0.0/0) que "passe batido".

  # Validação 1: precisa ser um CIDR válido (ex.: 200.100.50.25/32).
  validation {
    condition     = can(cidrhost(var.cidr_ssh, 0))
    error_message = "cidr_ssh precisa ser um CIDR válido, ex.: 200.100.50.25/32."
  }

  # Validação 2 (CA-03.1): a faixa precisa ser PEQUENA. O número depois da
  # "/" é o tamanho do prefixo: quanto MAIOR o número, MENOR a faixa.
  #   /32 -> 1 endereço (só o seu IP)
  #   /24 -> 256 endereços
  #   /0  -> TODOS os endereços da internet (0.0.0.0/0)
  # Exigir /24 ou maior barra o 0.0.0.0/0 e também "disfarces" como
  # 0.0.0.0/1, que liberaria metade da internet e passaria por uma checagem
  # que só comparasse o texto com "0.0.0.0/0".
  #
  # split("/", ...) separa "200.100.50.25/32" em ["200.100.50.25", "32"]; o
  # [1] pega o "32", e o tonumber() o converte em número. O try() devolve
  # false se algo falhar (ex.: texto sem "/"), em vez de gerar um erro
  # confuso.
  validation {
    condition     = try(tonumber(split("/", var.cidr_ssh)[1]) >= 24, false)
    error_message = "cidr_ssh é amplo demais: use o seu IP com /32 (no máximo /24). Liberar SSH para a internet (ex.: 0.0.0.0/0) não é permitido."
  }
}

variable "cidr_http" {
  description = "Faixa de IPs autorizada a acessar a API (porta 80)."
  type        = string
  # A API é pública por definição, então o padrão libera a internet toda.
  # Durante os testes, dá para restringir ao seu IP (/32).
  default = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.cidr_http, 0))
    error_message = "cidr_http precisa ser um CIDR válido, ex.: 0.0.0.0/0 ou 200.100.50.25/32."
  }
}
