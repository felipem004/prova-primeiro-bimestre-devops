#!/usr/bin/env bash
# =============================================================================
# criar-bucket.sh: cria o bucket S3 do state do Terraform (via AWS CLI)
# -----------------------------------------------------------------------------
# Por que este script existe: no Learner Lab, o recurso "aws_s3_bucket" do
# Terraform falha, porque uma SCP da organização do AWS Academy bloqueia a
# leitura da configuração de Object Lock que o provider sempre faz (ver
# infra/specs/design.md, §4). Então o bucket é criado aqui, e as
# configurações dele (versionamento, criptografia etc.) continuam no
# Terraform, no main.tf desta pasta.
#
# Como usar (na pasta infra/backend/, com as credenciais do lab carregadas):
#     bash criar-bucket.sh
#
# O script é IDEMPOTENTE: pode ser executado várias vezes sem problema. Se o
# bucket já existir, ele avisa e não faz nada.
# =============================================================================

# Modo "estrito" do Bash:
#   -e          -> para o script no primeiro comando que falhar;
#   -u          -> trata o uso de variável não definida como erro (evita, por
#                  exemplo, criar um bucket com o nome incompleto);
#   -o pipefail -> um erro em qualquer parte de um "cmd1 | cmd2" conta como
#                  erro (sem isso, só o resultado do último comando conta).
set -euo pipefail

# Os mesmos valores padrão das variáveis do Terraform (variables.tf). Podem
# ser trocados na chamada, ex.: AWS_REGION=us-west-2 bash criar-bucket.sh
NOME_PROJETO="${NOME_PROJETO:-api-reservas}"
REGIAO="${AWS_REGION:-us-east-1}"

# ID da conta: a mesma informação que o Terraform obtém com o
# data "aws_caller_identity". --query filtra só o campo "Account" e
# --output text devolve o valor puro, sem aspas nem JSON.
ID_CONTA="$(aws sts get-caller-identity --query Account --output text)"

# O nome precisa ser IDÊNTICO ao local.nome_bucket do main.tf; caso
# contrário, o Terraform configuraria um bucket que não existe.
NOME_BUCKET="${NOME_PROJETO}-tfstate-${ID_CONTA}"

# head-bucket verifica se o bucket existe e se temos acesso a ele. A saída é
# descartada (> /dev/null 2>&1), porque só interessa se deu certo ou não.
if aws s3api head-bucket --bucket "$NOME_BUCKET" > /dev/null 2>&1; then
  echo "O bucket do state já existe. Nada a fazer."
  exit 0
fi

echo "Criando o bucket do state na região ${REGIAO}..."

# Particularidade da AWS: na us-east-1 (a região "original"), o create-bucket
# NÃO aceita o parâmetro LocationConstraint; nas demais regiões, ele é
# obrigatório.
if [ "$REGIAO" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$NOME_BUCKET" --region "$REGIAO" > /dev/null
else
  aws s3api create-bucket --bucket "$NOME_BUCKET" --region "$REGIAO" \
    --create-bucket-configuration "LocationConstraint=${REGIAO}" > /dev/null
fi

# Buckets novos já nascem com bloqueio de acesso público, ACLs desativadas e
# criptografia SSE-S3. O versionamento, que não vem ligado, e a declaração
# explícita dessas proteções ficam a cargo do Terraform (main.tf).
echo "Bucket criado. Próximo passo: terraform plan / apply nesta pasta."
