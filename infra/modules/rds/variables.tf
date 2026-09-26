# =============================================================================
# modules/rds/variables.tf: entradas do módulo de banco de dados
# =============================================================================

variable "nome" {
  description = "Prefixo usado no identificador do banco e nas tags."
  type        = string
}

variable "ids_subredes_privadas" {
  description = "IDs das sub-redes privadas (output do módulo vpc), em pelo menos 2 AZs."
  type        = list(string)
}

variable "id_sg_rds" {
  description = "ID do Security Group do RDS (output do módulo security-group)."
  type        = string
}

variable "nome_banco" {
  description = "Nome do banco de dados criado dentro da instância PostgreSQL."
  type        = string
  default     = "reservas"
}

variable "usuario" {
  description = "Usuário principal (master) do banco."
  type        = string
  default     = "reservas_app"
}

variable "senha" {
  description = "Senha do usuário principal do banco."
  type        = string

  # sensitive = true: o Terraform ESCONDE o valor na saída do plan/apply,
  # mostrando "(sensitive value)". ATENÇÃO: isso NÃO criptografa nada. O
  # valor continua em texto puro no STATE (por isso o bucket é privado e
  # criptografado; ver design §8).
  sensitive = true
}

variable "classe_instancia" {
  description = "Classe (tamanho) da instância RDS. db.t3.micro é a menor disponível no Learner Lab."
  type        = string
  default     = "db.t3.micro"
}
