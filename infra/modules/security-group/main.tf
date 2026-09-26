# =============================================================================
# modules/security-group/main.tf: firewalls da EC2 e do RDS
# -----------------------------------------------------------------------------
# Atende: RF-03 (CA-03.1, CA-03.2) e CA-S.4 · design §6.2
#
# Um SECURITY GROUP (SG) é um firewall virtual ligado a um recurso (EC2,
# RDS...). Conceitos importantes:
#   - Por padrão, NEGA toda entrada. Só passa o que uma regra libera.
#   - É "STATEFUL": se uma conexão de entrada foi permitida, a RESPOSTA sai
#     automaticamente, sem precisar de regra de saída.
#   - Uma regra pode liberar uma faixa de IPs (CIDR) ou OUTRO SG: "qualquer
#     recurso que esteja no SG X". É isso que usamos para o banco.
#
# Estilo das regras: cada regra é um RECURSO SEPARADO
# (aws_vpc_security_group_ingress_rule / egress_rule), que é a forma
# recomendada pelo provider atual. Os blocos "ingress {}" dentro do SG são o
# estilo antigo, que dificulta alterar uma regra sem mexer nas outras.
# =============================================================================

# -----------------------------------------------------------------------------
# SG da EC2 (servidor da API)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.nome}-sg-ec2"
  description = "API de Reservas: HTTP publico e SSH restrito"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.nome}-sg-ec2"
  }
}

# Entrada HTTP (porta 80): acesso à API.
resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTP da API"

  ip_protocol = "tcp"
  from_port   = 80 # from/to definem uma FAIXA de portas; aqui, só a 80
  to_port     = 80
  cidr_ipv4   = var.cidr_http
}

# Entrada SSH (porta 22): administração, SOMENTE a partir do IP informado
# (CA-03.1). A validação em variables.tf impede faixas amplas.
resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "SSH somente do IP do administrador"

  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_ipv4   = var.cidr_ssh
}

# Saída: tudo liberado. A EC2 precisa sair para a internet (dnf, git clone,
# imagens Docker, certificado do RDS) e para o banco (porta 5432).
#
# Detalhe: a AWS cria essa regra de saída automaticamente em todo SG novo,
# mas o Terraform a REMOVE ao criar o SG, para que só existam as regras
# declaradas no código. Por isso ela precisa ser declarada aqui.
resource "aws_vpc_security_group_egress_rule" "ec2_saida" {
  security_group_id = aws_security_group.ec2.id
  description       = "Saida liberada (pacotes, git, Docker, RDS)"

  ip_protocol = "-1" # "-1" = todos os protocolos (e, portanto, todas as portas)
  cidr_ipv4   = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# SG do RDS (banco de dados)
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.nome}-sg-rds"
  description = "PostgreSQL: acesso somente a partir da EC2 da API"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.nome}-sg-rds"
  }
}

# Entrada PostgreSQL (porta 5432), SOMENTE de quem estiver no SG da EC2
# (CA-03.2).
#
# Por que referenciar o SG, e não o IP da EC2? O IP muda (por exemplo, quando
# a instância é recriada ou religada), e a regra ficaria desatualizada. Com a
# referência, a regra vale para "qualquer recurso no SG da EC2", seja qual
# for o IP dele. E nenhum IP de fora da VPC consegue usar essa regra.
resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL somente a partir do SG da EC2"

  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ec2.id
}

# O SG do RDS NÃO tem regra de saída, de propósito: o banco só RESPONDE
# conexões (e o SG é stateful, então as respostas saem sozinhas). Ele nunca
# precisa INICIAR uma conexão. Se o banco fosse comprometido, não conseguiria
# abrir conexões para fora.
