# Design: Infraestrutura AWS da API de Reservas (Terraform)

> **Fase 2 de 3 do Spec-Driven Development:** requisitos → **design** → tarefas.
> Este documento define **como** a infraestrutura será construída para atender
> ao `requirements.md`. Cada decisão aponta o requisito (RF/RNF/CA) ou a
> restrição (R-xx) que ela atende.
>
> **Status:** aprovado em 26/09/2026.

---

## 1. Visão geral da arquitetura

```
                         Internet
                            │
                   ┌────────▼────────┐
                   │ Internet Gateway │
                   └────────┬────────┘
┌─ VPC 10.0.0.0/16 ─────────┼──────────────────────────────────────────┐
│                           │                                          │
│  ┌─ Sub-rede pública 10.0.1.0/24 (AZ a) ─┐                            │
│  │  EC2 (t3.micro, Amazon Linux 2023)    │   SG "ec2":                │
│  │  └─ container da API (porta 80→3000)  │   80  ← var.http_cidr      │
│  └──────────────────┬────────────────────┘   22  ← var.ssh_cidr       │
│                     │ 5432 (SSL obrigatório)                          │
│  ┌─ Sub-rede privada 10.0.11.0/24 (AZ a) ─┐ ┌─ Privada 10.0.12.0/24 (AZ b) ─┐
│  │  RDS PostgreSQL 17 (db.t3.micro)       │ │  (reserva do DB subnet group) │
│  └────────────────────────────────────────┘ └───────────────────────────────┘
│                                              SG "rds": 5432 ← SG "ec2"│
└───────────────────────────────────────────────────────────────────────┘

State remoto (projeto separado, infra/backend/):
  S3 "api-reservas-tfstate-<id da conta>"  +  DynamoDB "api-reservas-tflock"
```

**Fluxo de uma requisição:** cliente → IP público da EC2, porta 80 → Docker
redireciona para a porta 3000 do container → API → RDS pela rede privada, na
porta 5432, com TLS.

## 2. Estrutura de arquivos

```
infra/
├── backend/                      # Projeto Terraform SEPARADO (state local)
│   ├── main.tf                   # bucket S3 + tabela DynamoDB
│   ├── variables.tf
│   ├── outputs.tf                # nome do bucket e da tabela
│   └── providers.tf
├── modules/
│   ├── vpc/                      # main.tf, variables.tf, outputs.tf
│   ├── security-group/           # main.tf, variables.tf, outputs.tf
│   ├── rds/                      # main.tf, variables.tf, outputs.tf
│   └── ec2/                      # main.tf, variables.tf, outputs.tf
│       └── user_data.sh.tftpl    # script de inicialização (template)
├── providers.tf                  # versões + provider AWS + backend "s3" (parcial)
├── main.tf                       # só compõe os módulos (CA-06.1)
├── variables.tf
├── outputs.tf
├── backend.hcl.example           # modelo da configuração do backend (vai pro Git)
├── terraform.tfvars.example      # modelo das variáveis (vai pro Git)
└── specs/                        # esta spec
```

Arquivos **locais, fora do Git** (já cobertos pelo `.gitignore`, exceto o
`backend.hcl`, que precisa de uma regra nova):
`terraform.tfvars`, `backend.hcl`, `.terraform/`, `*.tfstate*`.

## 3. Versões (CA-Q.2)

| Item | Restrição | Motivo |
|------|-----------|--------|
| Terraform | `required_version = "~> 1.16"` | Aceita 1.16.x e superiores dentro da versão 1 (ex.: 1.17), mas não a 2.0, que pode ter mudanças incompatíveis. |
| Provider AWS | `version = "~> 6.0"` | Série atual do provider. O `.terraform.lock.hcl` (gerado no `init`) trava a versão exata e **deve ir para o Git**, igual ao `package-lock.json`. |

## 4. `infra/backend/`: state remoto (RF-01)

**Por que é um projeto separado (CA-01.4):** o bucket precisa existir
**antes** de qualquer projeto guardar o state nele. Então o `backend/` roda
primeiro, com state **local** (`infra/backend/terraform.tfstate`, que é
ignorado pelo Git e **não pode ser perdido**).

> **Revisão (26/09/2026): desvio do design original.** No primeiro `apply`,
> o recurso `aws_s3_bucket` criou o bucket, mas falhou logo em seguida: o
> provider sempre lê a configuração de Object Lock
> (`s3:GetBucketObjectLockConfiguration`), e essa leitura é **negada por uma
> SCP** da organização do AWS Academy, que nenhuma permissão da conta
> consegue contornar. Por isso:
>
> - O **bucket** é criado **fora do Terraform**, pelo script
>   `infra/backend/criar-bucket.sh` (AWS CLI), que fica versionado e é
>   idempotente (não faz nada se o bucket já existir).
> - As **configurações** do bucket (versionamento, criptografia, bloqueio
>   público e ownership) e a **tabela DynamoDB** continuam no Terraform. Elas
>   referenciam o bucket **pelo nome**, sem o recurso `aws_s3_bucket`.
> - Consequência: a exigência "S3 + DynamoDB via Terraform" (CA-01.1) fica
>   atendida **parcialmente**, com justificativa registrada no relatório. O
>   `terraform destroy` não apaga o bucket; isso vira um passo manual na T-13.

| Recurso | Configuração | Requisito |
|---------|--------------|-----------|
| Bucket (via `criar-bucket.sh`) | Nome `api-reservas-tfstate-<account_id>`. Nomes de bucket são **globais** na AWS, e o ID da conta garante que o nome seja único. No Terraform, o mesmo nome é montado com `data "aws_caller_identity"`. | CA-01.1 (parcial) |
| `aws_s3_bucket_versioning` | `Enabled`: cada escrita do state gera uma versão, e dá para recuperar um state corrompido. | CA-S.2 |
| `aws_s3_bucket_server_side_encryption_configuration` | `AES256` (SSE-S3): criptografia gerenciada pela AWS, sem custo extra de KMS. | CA-S.2 |
| `aws_s3_bucket_public_access_block` | Os 4 bloqueios em `true`. | CA-S.2 |
| `aws_s3_bucket_ownership_controls` | `BucketOwnerEnforced`: desativa ACLs e deixa o acesso controlado só por políticas. | CA-S.2 |
| `aws_dynamodb_table` | Nome `api-reservas-tflock`, `billing_mode = "PAY_PER_REQUEST"` (paga só pelo uso, que é quase zero), chave `LockID` do tipo `S`. O nome e o tipo da chave são **exigidos** pelo backend S3. | CA-01.1, CA-01.3 |

**Destruição (CA-C.2):** como o bucket não é gerenciado pelo Terraform, o
`terraform destroy` do `backend/` apaga só a tabela e as configurações. O
bucket (versionado, com todas as versões do state) é esvaziado e apagado
manualmente com o AWS CLI, **por último**. Isso também elimina o risco de um
`destroy` apagar o state por acidente. O procedimento completo fica
documentado no `tasks.md`.

## 5. Configuração do backend e do provider (`infra/providers.tf`)

**Problema:** o bloco `backend "s3"` **não aceita variáveis**, e o nome do
bucket contém o ID da conta AWS.

**Decisão: configuração parcial do backend.** O `providers.tf` declara só o
que é fixo; o resto vem de um arquivo `backend.hcl`, informado no
`terraform init -backend-config=backend.hcl`.

```hcl
# providers.tf (parte fixa, vai para o Git)
backend "s3" {
  key     = "api-reservas/terraform.tfstate"
  encrypt = true
}

# backend.hcl (local, fora do Git), gerado a partir do backend.hcl.example
bucket         = "api-reservas-tfstate-<account_id>"
dynamodb_table = "api-reservas-tflock"
region         = "us-east-1"
```

O ID da conta não é uma senha, mas não precisa estar num repositório público:
ele facilita reconhecimento e ataques direcionados à conta.

⚠️ **Risco a verificar na implementação:** o `dynamodb_table` está obsoleto
desde o Terraform 1.11 (Q-04). Na 1.16.4 ele deve gerar apenas um **aviso**
de obsolescência no `init`. Se gerar **erro**, a alternativa é voltar à Q-04
e decidir de novo com você.

> **Verificado (26/09/2026, T-05):** na 1.16.4, o `dynamodb_table` gera só o
> aviso `Deprecated Parameter` ("Use parameter use_lockfile instead") e
> continua funcionando. A Q-04 se mantém.

**Provider:**
- Credenciais: **não** aparecem no código. O provider usa a cadeia padrão da
  AWS, que começa pelas **variáveis de ambiente** (`AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). Elas são carregadas com
  `source aws-credentials.sh`, um arquivo local e ignorado pelo Git,
  atualizado com os dados do "AWS Details" do Learner Lab a cada sessão
  (R-02).
- `region = var.aws_region`, com padrão `us-east-1` (R-03).
- `default_tags`: `Projeto = "api-reservas"`, `Ambiente = "lab"`,
  `GerenciadoPor = "terraform"` (CA-Q.4).

## 6. Módulos: responsabilidades e interfaces

O `main.tf` da raiz liga os outputs de um módulo às variáveis do outro.
Ordem de dependência (o Terraform deduz sozinho a partir das referências):

```
vpc ──► security-group ──► rds ──► ec2
  └───────────────────────────────►┘ (sub-rede pública)
```

A `ec2` depende do `rds` porque precisa do **endpoint** do banco para
configurar a API.

### 6.1 `modules/vpc` (RF-02)

| Entrada | Tipo | Padrão |
|---------|------|--------|
| `nome` | string | — |
| `cidr_vpc` | string | `10.0.0.0/16` |
| `cidr_subrede_publica` | string | `10.0.1.0/24` |
| `cidrs_subredes_privadas` | list(string) | `["10.0.11.0/24", "10.0.12.0/24"]` |

Recursos: `aws_vpc` (com `enable_dns_hostnames = true`, exigido para o
endpoint do RDS resolver dentro da VPC), `aws_internet_gateway`, 1 sub-rede
pública (`map_public_ip_on_launch = true`) + tabela de rotas com
`0.0.0.0/0 → IGW`, 2 sub-redes privadas em AZs diferentes, obtidas com
`data "aws_availability_zones"`, **sem** rota para a internet (CA-02.3).

| Saída | Usada por |
|-------|-----------|
| `vpc_id` | security-group |
| `id_subrede_publica` | ec2 |
| `ids_subredes_privadas` | rds |

### 6.2 `modules/security-group` (RF-03)

| Entrada | Tipo | Observação |
|---------|------|------------|
| `nome`, `vpc_id` | string | — |
| `cidr_ssh` | string | **Obrigatória, sem padrão.** Um bloco `validation` **rejeita** `0.0.0.0/0` (CA-03.1). Ex.: `"200.100.50.25/32"` (seu IP). |
| `cidr_http` | string | Padrão `0.0.0.0/0`: a API é pública por definição. Pode ser restringida ao seu IP durante os testes. |

Recursos, no estilo atual do provider (uma regra por recurso, com
`aws_vpc_security_group_ingress_rule`/`egress_rule` em vez de blocos inline):

| SG | Regra | Origem/destino |
|----|-------|----------------|
| `ec2` | entrada TCP 80 | `var.cidr_http` |
| `ec2` | entrada TCP 22 | `var.cidr_ssh` |
| `ec2` | saída: tudo | `0.0.0.0/0`, necessária para `dnf`, `git clone`, imagens Docker e o RDS |
| `rds` | entrada TCP 5432 | **SG `ec2`** (`referenced_security_group_id`), CA-03.2 |
| `rds` | saída: nenhuma | O banco só **responde** conexões, e SGs são *stateful* (a resposta sai automaticamente). |

| Saída | Usada por |
|-------|-----------|
| `id_sg_ec2` | ec2 |
| `id_sg_rds` | rds |

### 6.3 `modules/rds` (RF-05)

| Entrada | Tipo | Padrão |
|---------|------|--------|
| `nome`, `ids_subredes_privadas`, `id_sg_rds` | — | — |
| `nome_banco` | string | `reservas` |
| `usuario` | string | `reservas_app` |
| `senha` | string, **`sensitive = true`** | — (vem do `terraform.tfvars` local) |
| `classe_instancia` | string | `db.t3.micro` (R-05) |

Recursos: `aws_db_subnet_group` (as 2 sub-redes privadas) e
`aws_db_instance` com:

| Argumento | Valor | Requisito/motivo |
|-----------|-------|------------------|
| `engine` / `engine_version` | `postgres` / `"17"` | CA-05.4. Só a versão principal: a AWS escolhe a menor versão mais recente. |
| `allocated_storage` / `storage_type` | `20` / `gp3` | Mínimo, R-04. |
| `publicly_accessible` | `false` | CA-05.2 |
| `storage_encrypted` | `true` | CA-05.3 |
| `multi_az` | `false` | CA-C.1 |
| `backup_retention_period` | `1` | Backup mínimo, sem custo relevante. |
| `skip_final_snapshot` | `true` | Ambiente de laboratório: sem snapshot ao destruir, para não sobrar recurso cobrando. **Em produção, seria `false`.** |
| `deletion_protection` | `false` | Idem; permite o `destroy` final. |
| `apply_immediately` | `true` | Aplica alterações na hora, sem esperar a janela de manutenção. |

**SSL:** no PostgreSQL 15+, o RDS já vem com `rds.force_ssl = 1`. Não é
preciso criar um parameter group: conexões sem TLS são recusadas por padrão.

| Saída | Usada por |
|-------|-----------|
| `endereco` (hostname, sem a porta) | ec2 → `DB_HOST` |
| `porta` | ec2 → `DB_PORT` |

### 6.4 `modules/ec2` (RF-04)

| Entrada | Tipo | Padrão |
|---------|------|--------|
| `nome`, `id_subrede_publica`, `id_sg_ec2` | — | — |
| `tipo_instancia` | string | `t3.micro` (R-05) |
| `nome_chave` | string | `vockey` (Q-02) |
| `url_repositorio` | string | URL HTTPS pública do repositório (Q-01) |
| `branch` | string | `main` |
| `db_host`, `db_porta`, `db_nome`, `db_usuario` | — | outputs do rds / variáveis |
| `db_senha` | string, **`sensitive = true`** | — |

**AMI:** `data "aws_ami"` com o filtro `al2023-ami-*-x86_64` e dono
`amazon`, pegando a mais recente. Amazon Linux 2023 porque é a distribuição
da AWS, tem o Docker no repositório oficial e usa o `dnf`, o mesmo do seu
Fedora.

**Endurecimento da instância:**

| Argumento | Valor | Por quê |
|-----------|-------|---------|
| `metadata_options.http_tokens` | `required` | Exige o **IMDSv2**. O IMDSv1 foi explorado em ataques de SSRF (o vazamento da Capital One, em 2019, é o caso clássico). |
| `metadata_options.http_put_response_hop_limit` | `1` | Os containers ficam um "salto" de rede além do host e, com limite 1, **não alcançam** o serviço de metadados. Como o `user_data` (com a senha) fica nesse serviço, isso protege a senha caso a API seja comprometida. |
| `root_block_device.encrypted` | `true` | Disco criptografado. |
| `user_data_replace_on_change` | `true` | Se o script mudar, a instância é **recriada**. Sem isso, a mudança não teria efeito, porque o `user_data` só roda no primeiro boot. |

**`user_data.sh.tftpl` (CA-04.2 e CA-04.3), o que o script faz no 1º boot:**

1. `set -euo pipefail`: para no primeiro erro, em vez de seguir em frente
   com um estado quebrado.
2. `dnf install -y docker git` e `systemctl enable --now docker`. O
   `enable` faz o Docker iniciar **a cada boot** (R-06).
3. Baixa o certificado da CA do RDS
   (`https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem`) para
   `/opt/api-reservas/certs/`.
4. `git clone --depth 1 --branch <branch> <url>` e `docker build` da pasta
   `app/` (o mesmo Dockerfile do ambiente local).
5. Grava as variáveis do banco em `/opt/api-reservas/api.env`, com
   `chmod 600` e dono root.
6. `docker run -d --restart unless-stopped`, com as mesmas proteções do
   Compose (`--read-only`, `--tmpfs /tmp`, `--cap-drop ALL`,
   `--security-opt no-new-privileges`), `-p 80:3000`, `--env-file` e o
   certificado montado como **somente leitura**, com `DB_SSL=true` e
   `DB_SSL_CA` apontando para ele (CA-04.4).

O `--restart unless-stopped` + o Docker habilitado no boot garantem que a
API volta sozinha quando o lab religar a EC2 (CA-04.3).

| Saída | Usada por |
|-------|-----------|
| `ip_publico` | outputs da raiz |

## 7. Variáveis e saídas da raiz (RF-06)

**`variables.tf`:** `aws_region` (padrão `us-east-1`), `cidr_ssh`
(obrigatória), `cidr_http`, `url_repositorio`, `db_senha` (`sensitive`,
obrigatória). Todas com `description` (CA-Q.3). Os valores reais ficam no
`terraform.tfvars` local; o modelo é o `terraform.tfvars.example`.

**Validação da senha:** um bloco `validation` exige no mínimo 16 caracteres
e rejeita os caracteres `/`, `@`, `"` e espaço, que o RDS **não aceita** na
senha principal.

**`outputs.tf`:** `url_api` (`http://<ip>/health`), `ip_publico_ec2`,
`comando_ssh` (`ssh -i labsuser.pem ec2-user@<ip>`) e `endpoint_rds`.
Nenhum output com senha (CA-06.2).

## 8. Riscos conhecidos e mitigações

| Risco | Mitigação | Risco residual |
|-------|-----------|----------------|
| **Senha no state** (Q-03): toda variável vai em texto puro para o state. | O bucket é privado, criptografado e versionado (seção 4). | Quem tiver acesso ao bucket lê a senha. Aceitável no lab. |
| **Senha no `user_data`**: o script é guardado pela AWS e pode ser lido por quem tem permissão de ver a instância (console/API) ou por qualquer processo **dentro** da EC2, via serviço de metadados. | IMDSv2 com hop limit 1 (os containers não acessam); `api.env` com `chmod 600`. | Quem acessa o console do lab consegue ver o script. A melhoria futura seria usar o **SSM Parameter Store** (SecureString) e a EC2 buscar a senha na inicialização. Fica **fora do escopo** por decisão da Q-03. |
| **Senha no `plan`**: a evidência vai para o Git. | Variáveis `sensitive` aparecem como `(sensitive value)` no plan, e o `templatefile` com um valor sensível também fica marcado como sensível. | **Revisar o arquivo** antes de commitar (CA-06.3). |
| Credenciais do lab vencem no meio do `apply`. | Iniciar o `apply` logo após renovar a sessão; o lock do DynamoDB evita que um `apply` interrompido seja atropelado por outro. | Pode ser necessário um `terraform force-unlock` manual. |
| O `dynamodb_table` pode ter sido removido na 1.16. | Verificar no primeiro `init` (seção 5). | Se falhar, rediscutir a Q-04. |

## 9. Rastreabilidade (requisito → onde é atendido)

| Requisito | Seção |
|-----------|-------|
| RF-01 (CA-01.1 a 01.4) | 4, 5 |
| RF-02 (CA-02.1 a 02.3) | 6.1 |
| RF-03 (CA-03.1, 03.2) | 6.2 |
| RF-04 (CA-04.1 a 04.4) | 6.4 |
| RF-05 (CA-05.1 a 05.4) | 6.3 |
| RF-06 (CA-06.1 a 06.3) | 6, 7, 8 |
| RNF-01 (segurança) | 4, 5, 6.2, 6.4, 8 |
| RNF-02 (custo) | 4, 6.3, 6.4 |
| RNF-03 (qualidade) | 3, 5, 7 |

## 10. Referências

- Backend S3 e configuração parcial:
  https://developer.hashicorp.com/terraform/language/backend/s3 e
  https://developer.hashicorp.com/terraform/language/backend#partial-configuration
- Restrições de versão:
  https://developer.hashicorp.com/terraform/language/expressions/version-constraints
- Arquivo de lock de dependências:
  https://developer.hashicorp.com/terraform/language/files/dependency-lock
- Validação de variáveis:
  https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules
- Regras de Security Group no provider AWS:
  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
- IMDSv2: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
- Restrições da senha principal do RDS:
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.Constraints
- Certificados SSL do RDS:
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html
