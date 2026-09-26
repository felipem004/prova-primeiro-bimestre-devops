# =============================================================================
# main.tf (backend): bucket S3 do state + tabela DynamoDB do lock
# -----------------------------------------------------------------------------
# Atende: RF-01 (CA-01.1) e RNF-01 (CA-S.2) · design §4
#
# Lembrete importante: o state do projeto principal vai conter SEGREDOS em
# texto puro (ex.: a senha do RDS). Por isso este bucket é tratado como um
# COFRE: privado, criptografado e versionado.
# =============================================================================

# -----------------------------------------------------------------------------
# Dados da conta
# -----------------------------------------------------------------------------
# Um bloco "data" LÊ informações que já existem na AWS, sem criar nada. Aqui
# ele pergunta "qual conta estou usando?" (a mesma chamada do
# "aws sts get-caller-identity" da T-02).
data "aws_caller_identity" "atual" {}

# "locals" são valores calculados, reaproveitados dentro do projeto. Não são
# entradas (como as variáveis): servem só para evitar repetição.
locals {
  # Nomes de bucket são GLOBAIS: nenhuma outra conta, no mundo inteiro, pode
  # ter um bucket com o mesmo nome. O ID da conta no final garante um nome
  # único, sem precisar inventar sufixos aleatórios.
  nome_bucket = "${var.nome_projeto}-tfstate-${data.aws_caller_identity.atual.account_id}"
}

# -----------------------------------------------------------------------------
# 1. Configurações do bucket S3 do state
# -----------------------------------------------------------------------------
# O BUCKET EM SI NÃO É CRIADO AQUI, e sim pelo script criar-bucket.sh.
#
# Motivo: o recurso "aws_s3_bucket" do provider, logo depois de criar o
# bucket, lê TODAS as configurações dele para gravar no state, inclusive o
# Object Lock (s3:GetBucketObjectLockConfiguration). No Learner Lab, essa
# leitura é negada por uma SCP (Service Control Policy) da organização do
# AWS Academy, e o recurso sempre falha. Ver o desvio registrado no
# design.md, §4.
#
# Desde a versão 4 do provider, cada configuração do bucket (versões,
# criptografia, bloqueio público...) é um recurso SEPARADO. Isso permite
# gerenciá-las no Terraform mesmo sem o recurso do bucket: basta informar o
# NOME do bucket (local.nome_bucket), que já existe na AWS.

# Versionamento: cada vez que o state é gravado, o S3 guarda uma NOVA versão
# e mantém as anteriores. Se um state for corrompido ou sobrescrito por
# engano, dá para voltar a uma versão antiga.
resource "aws_s3_bucket_versioning" "state" {
  bucket = local.nome_bucket

  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia no servidor ("at rest"): os arquivos ficam criptografados no
# disco da AWS. AES256 = SSE-S3, com chaves gerenciadas pela própria AWS, sem
# custo extra (a alternativa, SSE-KMS, cobra por chave e por requisição).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = local.nome_bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueio de acesso público: os 4 bloqueios juntos impedem que o bucket ou
# qualquer objeto dele fique público, mesmo que alguém crie, por engano, uma
# política ou ACL permissiva no futuro.
#
# Buckets novos já nascem com esses bloqueios ligados, mas declarar aqui
# deixa a proteção DOCUMENTADA no código, e o Terraform a restaura se alguém
# a desligar pelo console.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = local.nome_bucket

  block_public_acls       = true # rejeita novas ACLs públicas
  ignore_public_acls      = true # ignora ACLs públicas que já existam
  block_public_policy     = true # rejeita políticas de bucket públicas
  restrict_public_buckets = true # restringe o acesso se houver política pública
}

# Propriedade dos objetos: "BucketOwnerEnforced" DESATIVA as ACLs (o sistema
# antigo de permissões, por objeto). Assim o acesso é controlado só por
# políticas IAM/de bucket, em um único lugar, o que é mais fácil de auditar.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = local.nome_bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# -----------------------------------------------------------------------------
# 2. Tabela DynamoDB do lock
# -----------------------------------------------------------------------------
# Quando alguém roda "plan" ou "apply", o Terraform grava um item nesta
# tabela ("estou usando o state"). Uma segunda execução ao mesmo tempo vê o
# item e é BLOQUEADA, o que evita que duas execuções sobrescrevam o state uma
# da outra e o corrompam (CA-01.3).
resource "aws_dynamodb_table" "lock" {
  name = "${var.nome_projeto}-tflock"

  # PAY_PER_REQUEST: sem capacidade reservada, paga só pelas leituras e
  # escritas. Como o lock é usado poucas vezes, o custo é praticamente zero.
  billing_mode = "PAY_PER_REQUEST"

  # O backend S3 do Terraform EXIGE uma chave primária chamada exatamente
  # "LockID", do tipo string ("S").
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Os dados do DynamoDB já são criptografados por padrão, com uma chave
  # gerenciada pela AWS, sem custo. Não é preciso configurar nada.
}
