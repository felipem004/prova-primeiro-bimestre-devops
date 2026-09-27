# =============================================================================
# modules/ec2/main.tf: servidor da API de Reservas
# -----------------------------------------------------------------------------
# Atende: RF-04 (CA-04.1 a CA-04.4) e CA-S.1 · design §6.4
#
# A EC2 roda a API em um container Docker, construído a partir do MESMO
# app/Dockerfile usado no ambiente local. Toda a preparação (instalar o
# Docker, baixar o código, fazer o build e subir o container) é feita
# automaticamente pelo script user_data.sh.tftpl no primeiro boot, sem
# nenhum passo manual (CA-04.2).
# =============================================================================

# -----------------------------------------------------------------------------
# Imagem do sistema operacional (AMI)
# -----------------------------------------------------------------------------
# Em vez de fixar um ID de AMI (que muda por região e fica desatualizado),
# pedimos à AWS a imagem MAIS RECENTE do Amazon Linux 2023 que atenda aos
# filtros. Assim a instância já nasce com as últimas correções de segurança.
data "aws_ami" "al2023" {
  most_recent = true

  # Só imagens publicadas pela própria Amazon. Sem esse filtro, uma AMI
  # maliciosa de terceiros, com um nome parecido, poderia ser escolhida.
  owners = ["amazon"]

  # "al2023-ami-2023.*" pega a versão padrão e exclui a "minimal", que vem
  # sem vários pacotes de que precisamos.
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# -----------------------------------------------------------------------------
# Instância EC2
# -----------------------------------------------------------------------------
resource "aws_instance" "api" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.tipo_instancia

  # Rede: sub-rede pública, com IP público (CA-04.1) e o SG da EC2.
  subnet_id                   = var.id_subrede_publica
  vpc_security_group_ids      = [var.id_sg_ec2]
  associate_public_ip_address = true

  # Par de chaves para o SSH (Q-02). A chave pública já existe na conta do
  # lab; a privada é o labsuser.pem, que fica só com você.
  key_name = var.nome_chave

  # ---------------------------------------------------------------------------
  # Script de inicialização (CA-04.2)
  # ---------------------------------------------------------------------------
  # templatefile() lê o arquivo .tftpl e SUBSTITUI cada ${...} dele pelos
  # valores passados aqui. O resultado é o script bash final.
  #
  # Como db_senha é sensitive, o Terraform marca o script inteiro como
  # sensitive: no plan, ele aparece como "(sensitive value)".
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    url_repositorio = var.url_repositorio
    branch          = var.branch
    db_host         = var.db_host
    db_porta        = var.db_porta
    db_nome         = var.db_nome
    db_usuario      = var.db_usuario
    db_senha        = var.db_senha
  })

  # O user_data só roda no PRIMEIRO boot. Se o script mudar, a única forma de
  # a mudança ter efeito é recriar a instância. Com "true", o Terraform faz
  # isso automaticamente (o plan mostra "must be replaced").
  user_data_replace_on_change = true

  # ---------------------------------------------------------------------------
  # Serviço de metadados (IMDS): endurecimento (design §6.4)
  # ---------------------------------------------------------------------------
  # O IMDS é um endereço especial (169.254.169.254) que responde, de dentro
  # da EC2, informações da instância, INCLUSIVE o user_data (com a senha).
  metadata_options {
    http_endpoint = "enabled"

    # IMDSv2 obrigatório: cada consulta exige um token obtido antes com uma
    # requisição PUT. Isso bloqueia ataques de SSRF, em que um invasor faz a
    # aplicação consultar o IMDS por ele (a técnica do vazamento da Capital
    # One, em 2019, que usou o IMDSv1).
    http_tokens = "required"

    # Hop limit 1: a resposta com o token só "sobrevive" a 1 salto de rede.
    # Os containers Docker ficam a 1 salto EXTRA do host, então o token não
    # chega até eles. Se a API for comprometida, o invasor não consegue ler
    # o user_data (nem a senha) pelo IMDS.
    http_put_response_hop_limit = 1
  }

  # Disco raiz criptografado, com chave gerenciada pela AWS. gp3 é o tipo de
  # SSD atual (mais barato que o gp2). O tamanho é o padrão da AMI (8 GB).
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.nome}-api"
  }
}
