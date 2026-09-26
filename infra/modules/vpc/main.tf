# =============================================================================
# modules/vpc/main.tf: rede da aplicação
# -----------------------------------------------------------------------------
# Atende: RF-02 (CA-02.1 a CA-02.3) · design §6.1
#
# O que este módulo cria:
#   - 1 VPC própria (a "rede privada virtual" do projeto na AWS);
#   - 1 Internet Gateway (a "porta" da VPC para a internet);
#   - 1 sub-rede PÚBLICA, com rota para a internet (EC2);
#   - 2 sub-redes PRIVADAS, sem rota para a internet (RDS).
#
# O que torna uma sub-rede "pública" ou "privada" NÃO é um atributo dela, e
# sim a TABELA DE ROTAS associada: se existe uma rota 0.0.0.0/0 apontando
# para o Internet Gateway, ela é pública; se não existe, é privada.
# =============================================================================

# -----------------------------------------------------------------------------
# Zonas de disponibilidade (AZs)
# -----------------------------------------------------------------------------
# Uma AZ é um ou mais data centers isolados dentro de uma região (ex.:
# us-east-1a, us-east-1b). Em vez de escrever os nomes à mão, perguntamos à
# AWS quais estão disponíveis. Assim o módulo funciona em qualquer região.
data "aws_availability_zones" "disponiveis" {
  state = "available"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "principal" {
  cidr_block = var.cidr_vpc

  # As duas opções abaixo ligam o DNS interno da VPC. São necessárias para
  # que o endpoint do RDS (ex.: xxx.rds.amazonaws.com) seja resolvido para o
  # IP PRIVADO do banco quando a EC2 o consulta.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.nome}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
# Sem ele, nada dentro da VPC fala com a internet, nem de dentro para fora
# nem de fora para dentro. A EC2 precisa dele para receber requisições da API
# e para baixar pacotes (dnf), o código (git clone) e imagens Docker.
resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${var.nome}-igw"
  }
}

# -----------------------------------------------------------------------------
# Sub-rede pública (CA-02.2)
# -----------------------------------------------------------------------------
resource "aws_subnet" "publica" {
  vpc_id     = aws_vpc.principal.id
  cidr_block = var.cidr_subrede_publica

  # Primeira AZ da lista (ex.: us-east-1a).
  availability_zone = data.aws_availability_zones.disponiveis.names[0]

  # Instâncias criadas nesta sub-rede recebem um IP público automaticamente
  # (CA-04.1). Sem isso, a EC2 teria só IP privado e ficaria inacessível.
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.nome}-subrede-publica"
  }
}

# Tabela de rotas da sub-rede pública: "tudo que não for da VPC (0.0.0.0/0),
# mande para o Internet Gateway". É ESTA rota que torna a sub-rede pública.
# O tráfego interno da VPC (10.0.0.0/16) tem uma rota "local" automática,
# criada pela própria AWS em toda tabela.
resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = {
    Name = "${var.nome}-rt-publica"
  }
}

# Associação: liga a sub-rede à tabela de rotas. Sem ela, a sub-rede usaria a
# tabela principal da VPC, que não tem rota para a internet.
resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}

# -----------------------------------------------------------------------------
# Sub-redes privadas (CA-02.3)
# -----------------------------------------------------------------------------
# "count" cria VÁRIAS cópias do mesmo recurso: uma para cada item da lista
# de CIDRs. Dentro do bloco, count.index vale 0, 1, 2...
resource "aws_subnet" "privada" {
  count = length(var.cidrs_subredes_privadas)

  vpc_id     = aws_vpc.principal.id
  cidr_block = var.cidrs_subredes_privadas[count.index]

  # Cada sub-rede em uma AZ DIFERENTE (0 -> us-east-1a, 1 -> us-east-1b...).
  # A função element() "dá a volta" na lista se houver mais sub-redes do que
  # AZs (índice 6 numa lista de 6 volta para o 0), em vez de dar erro.
  availability_zone = element(data.aws_availability_zones.disponiveis.names, count.index)

  # Nada de IP público aqui: o banco nunca deve ser alcançável da internet.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.nome}-subrede-privada-${count.index + 1}"
  }
}

# Tabela de rotas das sub-redes privadas: propositalmente SEM nenhuma rota
# (só a "local", automática). Assim elas não têm saída nem entrada pela
# internet.
#
# Poderíamos deixar as sub-redes na tabela principal da VPC, que também não
# tem rota para a internet. Mas uma tabela explícita deixa a intenção clara
# no código e protege contra alguém adicionar, no futuro, uma rota para a
# internet na tabela principal.
resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${var.nome}-rt-privada"
  }
}

resource "aws_route_table_association" "privada" {
  count = length(aws_subnet.privada)

  subnet_id      = aws_subnet.privada[count.index].id
  route_table_id = aws_route_table.privada.id
}
