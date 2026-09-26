# Requisitos: Infraestrutura AWS da API de Reservas (Terraform)

> **Fase 1 de 3 do Spec-Driven Development:** requisitos → design → tarefas.
> Este documento define **o que** a infraestrutura precisa entregar e **como
> verificar** que entregou. Ele ainda não define **como** construir; isso fica
> para o `design.md`.
>
> **Status:** aprovado em 26/09/2026.

---

## 1. Contexto

A API de Reservas (Node.js/Express + PostgreSQL) já roda localmente com Docker
Compose. Agora ela precisa de uma infraestrutura na AWS, escrita em Terraform,
**modularizada** e com **state remoto**, como pede a estrutura do cliente:

```
infra/
├── modules/{vpc, security-group, ec2, rds}/
├── main.tf / variables.tf / outputs.tf
├── providers.tf        # provider AWS + backend S3
└── backend/            # S3 + DynamoDB para o remote state
```

## 2. Restrições do ambiente (AWS Academy Learner Lab)

Estas restrições vêm da conta de estudante e **limitam as escolhas de design**.
Todas foram conferidas no **Readme do próprio laboratório** (botão "Readme" na
página do Learner Lab).

| ID | Restrição | Consequência para o projeto |
|----|-----------|-----------------------------|
| R-01 | Não é possível criar usuários, grupos ou roles IAM. | Nenhum recurso `aws_iam_*` no Terraform. Se a EC2 precisar de uma role, usar a que já existe (`LabInstanceProfile`/`LabRole`). |
| R-02 | As credenciais são **temporárias** (Access Key + Secret Key + **Session Token**) e expiram ao fim da sessão do lab (~4 h). | As credenciais precisam ser renovadas a cada sessão e **nunca** podem entrar em arquivos `.tf`, `.tfvars` ou no Git. |
| R-03 | A região é a padrão do laboratório (normalmente `us-east-1`). | A região fica em uma variável com esse valor padrão, sem região "escondida" no código. |
| R-04 | Orçamento de **50 créditos (USD)** para toda a implementação e os testes; ao atingir o limite, a conta é desativada. | Priorizar recursos baratos (instâncias pequenas, sem NAT Gateway, sem Multi-AZ). |
| R-05 | Tipos de instância EC2 e classes do RDS são limitados. | Usar as classes pequenas (ex.: `t3.micro`/`db.t3.micro`). |
| R-06 | Quando a sessão termina, as instâncias EC2 são **paradas**, mas não apagadas. | A API precisa voltar a funcionar sozinha quando a EC2 for ligada de novo. |

## 3. Requisitos funcionais

Formato: cada requisito tem um ID (RF-xx) e **critérios de aceite** (CA)
verificáveis, no estilo "QUANDO/ENTÃO".

### RF-01: State remoto (`infra/backend/`)
O state do Terraform da infraestrutura principal deve ficar armazenado
remotamente, e não no computador do desenvolvedor.

- **CA-01.1:** O projeto `infra/backend/` cria um bucket **S3** para o state e
  uma tabela **DynamoDB** para o lock, como exige a estrutura do cliente.
- **CA-01.2:** QUANDO `terraform init` rodar em `infra/`, ENTÃO o backend S3
  deve ser usado (sem arquivo `terraform.tfstate` local em `infra/`).
- **CA-01.3:** QUANDO duas execuções de `terraform apply` rodarem ao mesmo
  tempo, ENTÃO a segunda deve ser bloqueada pelo lock.
- **CA-01.4:** O `infra/backend/` tem o **próprio** state local, porque ele
  cria o bucket e não pode guardar o state dentro de um bucket que ainda não
  existe (o problema do "ovo e da galinha").

### RF-02: Rede (`modules/vpc`)
- **CA-02.1:** Uma VPC própria (não usar a VPC padrão da conta).
- **CA-02.2:** Pelo menos 1 sub-rede **pública**, com rota para um Internet
  Gateway, onde fica a EC2.
- **CA-02.3:** Pelo menos 2 sub-redes **privadas**, em **zonas de
  disponibilidade diferentes**, sem rota para a internet. O RDS exige um
  "DB subnet group" com sub-redes em ao menos 2 AZs, mesmo sem Multi-AZ.

### RF-03: Controle de acesso de rede (`modules/security-group`)
- **CA-03.1:** Um Security Group da EC2 que permite entrada **somente** na
  porta da API (HTTP) e, se houver SSH, somente a partir de um IP informado
  por variável (nunca `0.0.0.0/0` na porta 22).
- **CA-03.2:** Um Security Group do RDS que permite entrada na porta 5432
  **somente** a partir do Security Group da EC2 (referência entre SGs, e não
  por faixa de IP).

### RF-04: Servidor da aplicação (`modules/ec2`)
- **CA-04.1:** Uma instância EC2 na sub-rede pública, com IP público.
- **CA-04.2:** QUANDO a instância terminar de inicializar, ENTÃO a API deve
  responder `200` em `GET /health`, **sem nenhum passo manual** (instalação e
  inicialização automatizadas via `user_data`).
- **CA-04.3:** QUANDO a instância for parada e ligada de novo, ENTÃO a API
  deve voltar a responder sozinha (R-06).
- **CA-04.4:** A API se conecta ao RDS com **SSL obrigatório e certificado
  verificado** (`DB_SSL=true` e `DB_SSL_CA`, já suportados pelo `db.js`).

### RF-05: Banco de dados (`modules/rds`)
- **CA-05.1:** Uma instância RDS PostgreSQL nas sub-redes privadas.
- **CA-05.2:** `publicly_accessible = false`.
- **CA-05.3:** Armazenamento **criptografado** (`storage_encrypted = true`).
- **CA-05.4:** A versão principal do PostgreSQL é a mesma do ambiente local
  (17), para que o comportamento seja igual nos dois ambientes.

### RF-06: Composição e saídas (`main.tf`, `variables.tf`, `outputs.tf`)
- **CA-06.1:** O `main.tf` da raiz só **compõe** os módulos, passando os
  outputs de um como entrada do outro. Nenhum recurso é criado diretamente
  na raiz.
- **CA-06.2:** Os outputs incluem, no mínimo, a URL pública da API e o
  endpoint do RDS. **Nenhum** output expõe senhas; se algum valor sensível
  precisar sair, ele fica marcado com `sensitive = true`.
- **CA-06.3:** QUANDO `terraform plan` rodar, ENTÃO a saída deve ser salva em
  `evidencias/terraform-plan.txt` **sem nenhum segredo** visível.

## 4. Requisitos não funcionais

### RNF-01: Segurança
- **CA-S.1:** Nenhuma credencial (AWS ou do banco) escrita em arquivos
  versionados. As credenciais da AWS ficam em `~/.aws/credentials` ou em
  variáveis de ambiente; a senha do banco vem de variável `sensitive`.
- **CA-S.2:** O **state contém segredos em texto puro** (inclusive a senha do
  RDS). Por isso, o bucket do state deve ter: bloqueio total de acesso
  público, criptografia no servidor e **versionamento** (para recuperar um
  state corrompido).
- **CA-S.3:** Arquivos `*.tfstate*`, `*.tfvars` e `.terraform/` continuam no
  `.gitignore` (já estão).
- **CA-S.4:** Princípio do menor privilégio na rede: o banco nunca fica
  alcançável pela internet, só a porta da API fica exposta.

### RNF-02: Custo
- **CA-C.1:** Sem NAT Gateway, sem Multi-AZ no RDS e com as menores classes de
  instância que atendam a API.
- **CA-C.2:** Existe um procedimento documentado de `terraform destroy` para
  apagar tudo ao final e não consumir créditos à toa.

### RNF-03: Qualidade do código
- **CA-Q.1:** `terraform fmt -check` e `terraform validate` passam sem erros.
- **CA-Q.2:** Versões do Terraform e do provider AWS **fixadas**
  (`required_version` e `required_providers`), para builds reproduzíveis,
  como fizemos com o `package-lock.json`.
- **CA-Q.3:** Todas as variáveis e outputs têm `description`.
- **CA-Q.4:** Todos os recursos recebem tags padrão (ex.: `Projeto`,
  `Ambiente`), via `default_tags` do provider.

## 5. Fora do escopo

- HTTPS/TLS na API (exigiria domínio e certificado): a API responde em HTTP.
- Alta disponibilidade (Auto Scaling, Load Balancer, Multi-AZ).
- Pipeline de CI/CD.

## 6. Decisões tomadas na revisão

Estas eram as questões em aberto do rascunho. Todas foram decididas na
revisão dos requisitos.

| ID | Questão | Decisão |
|----|---------|---------|
| Q-01 | Como o código da API chega à EC2? | `git clone` do repositório **público** + `docker build` na própria EC2. |
| Q-02 | Acesso administrativo à EC2. | SSH com a chave `vockey` do lab, com a porta 22 liberada **somente** para o IP do desenvolvedor. |
| Q-03 | Como a senha do RDS é informada. | Variável Terraform com `sensitive = true`. |
| Q-04 | Mecanismo de lock do state. | Somente **DynamoDB**, como exige o cliente (sem `use_lockfile`). |
| Q-05 | Versão do Terraform. | **v1.16.4** instalada; o `required_version` será `~> 1.16`. |

## 7. Referências

- Terraform, backend S3 (inclui `use_lockfile` e a obsolescência do DynamoDB):
  https://developer.hashicorp.com/terraform/language/backend/s3
- Terraform, módulos: https://developer.hashicorp.com/terraform/language/modules
- Terraform, dados sensíveis no state:
  https://developer.hashicorp.com/terraform/language/state/sensitive-data
- AWS, requisitos do DB subnet group (2 AZs):
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html
- AWS, SSL/TLS com o RDS PostgreSQL:
  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html
- AWS Academy Learner Lab: consultar o **Readme** dentro do próprio laboratório.
