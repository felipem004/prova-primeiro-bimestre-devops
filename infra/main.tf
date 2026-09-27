# =============================================================================
# main.tf: composição dos módulos (projeto principal)
# -----------------------------------------------------------------------------
# Atende: CA-06.1 · design §6
#
# Este arquivo NÃO cria recursos diretamente. Ele só CHAMA os módulos e liga
# a saída de um à entrada do outro. O Terraform descobre sozinho a ordem de
# criação a partir dessas referências (ex.: se o módulo B usa module.A.x, o
# A é criado primeiro).
#
# Ordem de dependência (design §6):
#   vpc -> security-group -> rds -> ec2
# =============================================================================

# Valores reaproveitados por todos os módulos.
locals {
  nome_projeto = "api-reservas"

  # Nome do banco e usuário: definidos UMA vez aqui e passados tanto ao
  # módulo rds (que os cria) quanto ao módulo ec2 (que os entrega à API).
  # Assim os dois lados nunca ficam com valores diferentes.
  db_nome    = "reservas"
  db_usuario = "reservas_app"
}

# -----------------------------------------------------------------------------
# Rede (T-06)
# -----------------------------------------------------------------------------
# "source" aponta para a pasta do módulo. Os CIDRs usam os valores padrão
# definidos no módulo (10.0.0.0/16 etc.), então só o nome é obrigatório.
module "vpc" {
  source = "./modules/vpc"

  nome = local.nome_projeto
}

# -----------------------------------------------------------------------------
# Firewalls (T-07)
# -----------------------------------------------------------------------------
# module.vpc.vpc_id é a SAÍDA do módulo vpc usada como ENTRADA deste. Essa
# referência é o que diz ao Terraform: "crie a VPC antes dos SGs".
module "security_group" {
  source = "./modules/security-group"

  nome      = local.nome_projeto
  vpc_id    = module.vpc.vpc_id
  cidr_ssh  = var.cidr_ssh
  cidr_http = var.cidr_http
}

# -----------------------------------------------------------------------------
# Banco de dados (T-08)
# -----------------------------------------------------------------------------
# Recebe as sub-redes privadas do módulo vpc e o SG do módulo
# security-group. A senha vem de uma variável sensitive (terraform.tfvars).
module "rds" {
  source = "./modules/rds"

  nome                  = local.nome_projeto
  ids_subredes_privadas = module.vpc.ids_subredes_privadas
  id_sg_rds             = module.security_group.id_sg_rds
  nome_banco            = local.db_nome
  usuario               = local.db_usuario
  senha                 = var.db_senha
}

# -----------------------------------------------------------------------------
# Servidor da API (T-09)
# -----------------------------------------------------------------------------
# Depende de TODOS os outros módulos: sub-rede (vpc), firewall
# (security-group) e o endereço do banco (rds). Por usar module.rds.endereco,
# a EC2 só é criada DEPOIS que o RDS estiver pronto (o que leva alguns
# minutos), e a API já encontra o banco disponível no primeiro boot.
module "ec2" {
  source = "./modules/ec2"

  nome               = local.nome_projeto
  id_subrede_publica = module.vpc.id_subrede_publica
  id_sg_ec2          = module.security_group.id_sg_ec2
  url_repositorio    = var.url_repositorio

  db_host    = module.rds.endereco
  db_porta   = module.rds.porta
  db_nome    = local.db_nome
  db_usuario = local.db_usuario
  db_senha   = var.db_senha
}
