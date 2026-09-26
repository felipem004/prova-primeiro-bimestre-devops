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
