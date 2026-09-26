# =============================================================================
# providers.tf (backend): versões e configuração do provider AWS
# -----------------------------------------------------------------------------
# Este é um projeto Terraform SEPARADO do projeto principal (infra/). Ele cria
# o bucket S3 e a tabela DynamoDB que vão guardar o state do projeto principal.
#
# Repare que aqui NÃO existe um bloco "backend": o state DESTE projeto fica
# LOCAL (infra/backend/terraform.tfstate). Ele não pode ficar no bucket,
# porque é justamente este projeto que cria o bucket (o problema do "ovo e da
# galinha", CA-01.4). O arquivo é ignorado pelo Git e NÃO PODE SER PERDIDO:
# sem ele, o Terraform "esquece" que o bucket e a tabela existem.
# =============================================================================

terraform {
  # "~> 1.16" aceita 1.16.x e as versões 1.x seguintes (1.17, 1.18...), mas
  # não a 2.0, que pode trazer mudanças incompatíveis (CA-Q.2).
  required_version = "~> 1.16"

  required_providers {
    aws = {
      # "hashicorp/aws" = registry.terraform.io/hashicorp/aws, o provider
      # oficial. Declarar a origem evita baixar um provider homônimo de outra
      # fonte.
      source = "hashicorp/aws"

      # "~> 6.0" aceita qualquer 6.x, mas não a 7.0. A versão EXATA baixada
      # fica registrada no .terraform.lock.hcl, gerado pelo "terraform init",
      # que deve ir para o Git (mesma ideia do package-lock.json).
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # As CREDENCIAIS não aparecem aqui. O provider as procura sozinho, nesta
  # ordem: variáveis de ambiente (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
  # AWS_SESSION_TOKEN, carregadas com "source aws-credentials.sh"), depois
  # ~/.aws/credentials, e assim por diante. Nunca escreva chaves neste arquivo.

  # default_tags: estas tags são aplicadas AUTOMATICAMENTE em todos os
  # recursos criados por este provider (CA-Q.4). Facilitam identificar, no
  # console da AWS, o que pertence ao projeto e o que foi criado pelo Terraform.
  default_tags {
    tags = {
      Projeto       = var.nome_projeto
      Ambiente      = "lab"
      GerenciadoPor = "terraform"
    }
  }
}
