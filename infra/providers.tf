# =============================================================================
# providers.tf: versões, backend do state e provider AWS (projeto principal)
# -----------------------------------------------------------------------------
# Atende: RF-01 (CA-01.2), CA-Q.2, CA-Q.4, R-03 · design §3 e §5
# =============================================================================

terraform {
  # Mesmas restrições de versão do projeto infra/backend/ (design §3).
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # ---------------------------------------------------------------------------
  # Backend S3: onde o STATE deste projeto fica guardado
  # ---------------------------------------------------------------------------
  # Em vez de um terraform.tfstate local, o state vai para o bucket criado na
  # Fase B, e a tabela DynamoDB faz o lock (CA-01.2, CA-01.3).
  #
  # CONFIGURAÇÃO PARCIAL: o bloco "backend" NÃO aceita variáveis, e o nome do
  # bucket contém o ID da conta AWS, que não deve ir para um repositório
  # público. Por isso, aqui ficam só os valores fixos; bucket, tabela e
  # região vêm do arquivo backend.hcl (local, ignorado pelo Git), informado
  # assim:
  #     terraform init -backend-config=backend.hcl
  # O modelo desse arquivo é o backend.hcl.example.
  backend "s3" {
    # Caminho do state DENTRO do bucket. O prefixo com o nome do projeto
    # permite, no futuro, guardar states de outros projetos no mesmo bucket
    # sem conflito.
    key = "api-reservas/terraform.tfstate"

    # Pede ao S3 que criptografe o state ao gravá-lo. O bucket já tem
    # criptografia padrão, mas declarar aqui garante a proteção mesmo que a
    # configuração do bucket mude.
    encrypt = true
  }
}

provider "aws" {
  # Região vinda de variável, com o padrão do Learner Lab (R-03).
  region = var.aws_region

  # Credenciais: NUNCA aqui. O provider as lê das variáveis de ambiente
  # carregadas com "source aws-credentials.sh" (design §5).

  # Tags aplicadas automaticamente em todos os recursos (CA-Q.4). São as
  # mesmas do backend, para que tudo do projeto seja identificado igual.
  default_tags {
    tags = {
      Projeto       = "api-reservas"
      Ambiente      = "lab"
      GerenciadoPor = "terraform"
    }
  }
}
