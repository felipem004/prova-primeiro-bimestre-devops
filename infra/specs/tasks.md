# Tarefas: Infraestrutura AWS da API de Reservas (Terraform)

> **Fase 3 de 3 do Spec-Driven Development:** requisitos → design → **tarefas**.
> Lista ordenada de passos pequenos para implementar o `design.md`. Regras:
>
> - **Uma tarefa por vez.** A próxima só começa quando a atual estiver
>   verificada.
> - Cada tarefa indica os **requisitos** que atende e **como verificar**.
> - A IA escreve os arquivos; **todos os comandos são executados pelo
>   desenvolvedor**, depois de explicados.
> - Legenda: `[ ]` pendente · `[x]` concluída.
>
> **Status:** aprovado em 26/09/2026; em execução.

---

## Fase A: Preparação

### [x] T-01: Regras novas no `.gitignore`
- **O quê:** adicionar `backend.hcl`, `*.tfplan` (arquivos de plan binários
  podem conter segredos) e `aws-credentials.sh` (credenciais do lab, T-02).
- **Atende:** CA-S.1, CA-S.3 · design §2, §5
- **Verificar:** `git check-ignore -v infra/backend.hcl aws-credentials.sh`
  aponta as regras novas.

### [ ] T-02: Credenciais do Learner Lab na máquina local
- **O quê (manual, pelo desenvolvedor):** as credenciais de "AWS Details →
  AWS CLI" ficam como **variáveis de ambiente** (`AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) no arquivo
  `aws-credentials.sh`, na raiz do projeto, **ignorado pelo Git** (T-01) e
  protegido com `chmod 600`. A cada nova sessão do lab, o desenvolvedor
  atualiza o arquivo e o carrega com `source aws-credentials.sh`, no mesmo
  terminal em que vai rodar o Terraform.
- **Atende:** R-02, CA-S.1
- **Verificar:** `aws sts get-caller-identity` responde sem erro de
  autenticação.

### [ ] T-03: Descobrir o IP público do desenvolvedor
- **O quê:** obter o seu IP público, que vira `cidr_ssh = "<ip>/32"`.
- **Atende:** CA-03.1
- **Atenção:** em redes domésticas, o IP pode mudar. Se o SSH parar de
  funcionar, atualize a variável e rode o `apply` de novo.

## Fase B: State remoto (`infra/backend/`)

### [ ] T-04: Projeto `backend/`
- **O quê:** `providers.tf`, `variables.tf`, `main.tf` e `outputs.tf` com o
  bucket S3 (versionado, criptografado, bloqueio público, BucketOwnerEnforced)
  e a tabela DynamoDB `api-reservas-tflock`.
- **Atende:** RF-01 (CA-01.1, CA-01.4), CA-S.2, CA-Q.2 a CA-Q.4 · design §4
- **Verificar:** `terraform fmt -check`, `terraform init`, `terraform
  validate`, `terraform plan` (revisar) e `terraform apply`. Depois do apply,
  os outputs mostram o nome do bucket e da tabela.
- **Commit sugerido:** `feat(infra): cria backend S3 + DynamoDB para o state remoto`
  (sem o `terraform.tfstate` local, que é ignorado).

## Fase C: Projeto principal (`infra/`)

### [ ] T-05: `providers.tf` e `backend.hcl.example`
- **O quê:** versões fixadas, provider AWS com `default_tags` e backend `s3`
  parcial. Criar o `backend.hcl.example` (modelo) e, **manualmente**, o
  `backend.hcl` local com o nome real do bucket.
- **Atende:** CA-01.2, CA-Q.2, CA-Q.4, R-03 · design §3, §5
- **Verificar:** `terraform init -backend-config=backend.hcl`.
  - Observar se o `dynamodb_table` gera **aviso** (ok) ou **erro** (voltar à
    Q-04). → **Risco d) do design.**
  - Nenhum `terraform.tfstate` local é criado em `infra/`.

### [ ] T-06: Módulo `vpc` + ligação no `main.tf`
- **O quê:** módulo completo (VPC, IGW, sub-rede pública + rotas, 2 sub-redes
  privadas em AZs diferentes) e a primeira chamada `module "vpc"` na raiz.
- **Atende:** RF-02 (CA-02.1 a 02.3), CA-06.1 · design §6.1
- **Verificar:** `terraform validate` e `terraform plan`: 2 sub-redes privadas
  em AZs diferentes, sem rota `0.0.0.0/0` nelas.

### [ ] T-07: Módulo `security-group`
- **O quê:** SGs `ec2` e `rds`, regras como recursos separados e validação que
  rejeita `0.0.0.0/0` no SSH.
- **Atende:** RF-03 (CA-03.1, CA-03.2), CA-S.4 · design §6.2
- **Verificar:** `terraform plan` mostra a 5432 liberada **só** a partir do SG
  da EC2. **Teste negativo:** com `cidr_ssh = "0.0.0.0/0"`, o `plan` falha
  com a mensagem da validação.

### [ ] T-08: Módulo `rds`
- **O quê:** DB subnet group + instância PostgreSQL 17 com os argumentos do
  design.
- **Atende:** RF-05 (CA-05.1 a 05.4), CA-C.1 · design §6.3
- **Verificar:** no `terraform plan`, `publicly_accessible = false`,
  `storage_encrypted = true` e a senha aparece como `(sensitive value)`.

### [ ] T-09: Módulo `ec2` + `user_data.sh.tftpl`
- **O quê:** AMI Amazon Linux 2023, instância com IMDSv2 (hop limit 1), disco
  criptografado, chave `vockey` e o script de inicialização.
- **Atende:** RF-04 (CA-04.1 a 04.4), CA-S.1 · design §6.4
- **Verificar:** `terraform plan` mostra `http_tokens = "required"` e
  `http_put_response_hop_limit = 1`, e o `user_data` **não** aparece em texto
  puro.

### [ ] T-10: Variáveis e saídas da raiz + `terraform.tfvars.example`
- **O quê:** `variables.tf` (com a validação da senha), `outputs.tf` e o
  modelo `terraform.tfvars.example`. Criar o `terraform.tfvars` local
  **manualmente**, com a senha gerada pelo desenvolvedor.
- **Atende:** RF-06 (CA-06.1, CA-06.2), CA-Q.3 · design §7
- **Verificar:** `terraform fmt -check -recursive` e `terraform validate`
  passam (CA-Q.1).

## Fase D: Evidência, aplicação e testes

### [ ] T-11: Plan como evidência
- **O quê:** salvar a saída do plan em `evidencias/terraform-plan.txt`.
- **Atende:** CA-06.3
- **Verificar:** **revisão manual** do arquivo antes do commit. Procurar a
  senha, o ID da conta e as credenciais da AWS; nada disso pode aparecer.

### [ ] T-12: `terraform apply` e testes de aceite
- **Atende:** validação final de todos os requisitos.
- **Verificar (checklist):**
  - [ ] `curl http://<ip>/health` → `200` (CA-04.2). Aguardar ~3 a 5 min
        após o apply, pelo tempo do `user_data`.
  - [ ] CRUD completo via `curl` (POST, GET, PUT, DELETE).
  - [ ] SSH com `labsuser.pem` funciona a partir do seu IP (Q-02).
  - [ ] Conexão direta do seu computador ao endpoint do RDS na 5432 **falha**
        (CA-05.2, CA-S.4).
  - [ ] Parar e ligar a EC2 → a API volta sozinha e os dados continuam lá
        (CA-04.3). Atenção: o **IP público muda** ao religar.
  - [ ] Duas execuções simultâneas de `terraform plan` → a segunda é
        bloqueada pelo lock (CA-01.3).
  - [ ] Nenhum arquivo `terraform.tfstate` local em `infra/` (CA-01.2).

## Fase E: Encerramento

### [ ] T-13: Procedimento de destruição (documentar e, ao final, executar)
- **Atende:** CA-C.2
- **Ordem obrigatória:**
  1. `terraform destroy` em `infra/` (EC2, RDS, rede).
  2. Esvaziar o bucket do state, **incluindo todas as versões** (bucket
     versionado), porque o `force_destroy` é `false`.
  3. `terraform destroy` em `infra/backend/`.
- **Por que essa ordem:** se o backend for destruído primeiro, o state da
  infraestrutura principal se perde, e os recursos ficam "órfãos": continuam
  existindo (e consumindo créditos), mas o Terraform não sabe mais que eles
  existem.
- **Quando:** só depois da entrega e da coleta de todas as evidências.
