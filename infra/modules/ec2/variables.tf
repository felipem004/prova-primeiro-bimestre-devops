# =============================================================================
# modules/ec2/variables.tf: entradas do módulo do servidor da API
# =============================================================================

variable "nome" {
  description = "Prefixo usado na tag Name da instância."
  type        = string
}

variable "id_subrede_publica" {
  description = "ID da sub-rede pública onde a EC2 será criada (output do módulo vpc)."
  type        = string
}

variable "id_sg_ec2" {
  description = "ID do Security Group da EC2 (output do módulo security-group)."
  type        = string
}

variable "tipo_instancia" {
  description = "Tipo (tamanho) da instância EC2. t3.micro: 2 vCPUs e 1 GB de RAM."
  type        = string
  default     = "t3.micro"
}

variable "nome_chave" {
  description = "Nome do par de chaves SSH já existente na conta. No Learner Lab, é a vockey."
  type        = string
  default     = "vockey"
}

# --- Código da aplicação ------------------------------------------------------

variable "url_repositorio" {
  description = "URL HTTPS pública do repositório Git com a pasta app/ (Dockerfile da API)."
  type        = string
}

variable "branch" {
  description = "Branch do repositório usada no git clone."
  type        = string
  default     = "main"
}

# --- Conexão com o banco (outputs do módulo rds e locals da raiz) -------------

variable "db_host" {
  description = "Hostname do RDS (DB_HOST da API)."
  type        = string
}

variable "db_porta" {
  description = "Porta do RDS (DB_PORT da API)."
  type        = number
}

variable "db_nome" {
  description = "Nome do banco (DB_NAME da API)."
  type        = string
}

variable "db_usuario" {
  description = "Usuário do banco (DB_USER da API)."
  type        = string
}

variable "db_senha" {
  description = "Senha do banco (DB_PASSWORD da API)."
  type        = string
  sensitive   = true
}
