### Relatório - Prova Devops ###

# Questão 1 — A Jornada Completa (Aulas 01 a 07)

Descreva como você conectou as peças do bimestre para entregar a API de Reservas: do versionamento (Git) à infraestrutura na nuvem (Terraform + módulos + remote state). Explique a ordem que seguiu e por quê. Onde cada aula (01 a 07) apareceu na sua solução?

## Resposta: 

Vou descrever meu fluxo de pensamento para realizar o projeto:

1 - Primeiro comecei lendo o contexto do projeto e tentei entender o porque estava fazendo ele.
2 - Segundo comecei por estruturar como seriam feitos meus commits e organização de tudo o que seria feito (antes mesmo de começar a utilizar a ferramenta de IA).
3 - Comecei pelos arquivos Dockerfile, .dockerignore e docker-compose.yml - providenciando toda a estrutura de containers que o projeto deveria ter - Nesse trecho em específico havia tido alguns problemas no passado com volumes persistentes em distribuições linux que utilizavam SELinux como sistema de defesa primário, então precisei ficar atento a esses pontos.
4 - Em seguida fui aos arquivos package-lock.json e package.json.
5 - Após isso demarquei um check-point - e foi a partir deste momento em que comecei a utilizar a IA no modo Spec-Driven.
6 - Desenhei junto a IA todo o mapa do que seria feito na infra-estrutura com terraform - Desde os requisitos (presentes no arquivo requirements.md), passando pelo design da aplicação (presentes no arquivo design.md) e por último o passo a passo de execução de tudo aquilo que deveria ser feito, sequencialmente, em conjunto com a IA (presentes no arquivo tasks.md).
7 - Após todo o desenvolvimento com o terraform - que foi, de longe, o que mais me tomou tempo - passei ao processo de conexão com o ec2 e rds e após isso, todos os testes e coleta de evidências.
8 - Finalizei destruindo a estrutura terraform (terraform destroy) e excluindo informações desnecessárias.

# Questão 2 — O Processo com IA como Copiloto

Qual ferramenta de IA você usou e como? Descreva os prompts principais, o que a IA gerou bem e o que precisou corrigir. Se usou Kiro Spec, descreva o fluxo requisitos → design → tarefas. Compare com fazer manualmente: onde a IA economizou tempo e onde atrapalhou?

## Resposta: 

A ferramenta de IA que utilizei foi o Claude Code.

O fluxo que utilizei foi o seguinte:
Comecei desenvolvendo a parte da estrutura docker em uma espécie de 'vibe coding' - porém revisava tudo o que ela fazia.

A partir do momento em que passei para o desenvolvimento da infra com o terraform (mencionado na resposta da questão 1) passei a mudar a estratégia e a forma de se trabalhar com a IA.

A primeira coisa que fiz foi setar um comando padrão para guardar todo o histórico de prompts de nossa sessão em um arquivo chamado 'historico_de_prompts.md' no formado de "Prompt recebido >> Resultado obtido", dessa forma facilitava tanto um rastreio futuro em nossa conversa quanto o requisito solicitado pelo professor em aula (informar o prompt usado para chegar ao resultado).

Em seguida mudei a forma de trabalhar para o modo 'Spec-Driven', onde passei a 'desenhar' todo o fluxo da próxima etapa do projeto - requisitos funcionais, não funcionais, detalhes, observações, restrições e fluxo de tarefas a serem executadas. 

Após todo o processo de tomada de decisão e correção nesses três documentos, passamos a executar as tarefas já definidas uma a uma.

Não tive muitos casos de erro em trabalhar com a ferramenta de IA. Minha principal dificuldade foi durante a fase de implementação do terraform na aws, onde tive alguns problemas com o bucket_s3, credenciais expirando, chaves ssh de autenticação falhando dentre outros, porém com  alguns prompts a mais consegui corrigir sem muita dor de cabeça.

O tempo total para a criação e teste de toda a estrutura foi de aproximadamente 9 horas de trabalho, com um total de mais de 90 prompts (total exato no arquivo 'historico_de_prompts.md').


# Questão 3 — Infraestrutura, Segurança e o Learner Lab

Explique a arquitetura AWS que você provisionou (pode incluir diagrama). Por que o RDS fica na subnet privada e a EC2 na pública? Como funcionou o uso do LabRole/LabInstanceProfile em vez de criar IAM próprio? Que ajustes o AWS Academy Learner Lab exigiu em relação ao que foi ensinado (credenciais temporárias, região, restrições de IAM)?

## Arquitetura provisionada

Terraform modularizado (`vpc`, `security-group`, `rds`, `ec2`) na região `us-east-1`, com state remoto em S3 e lock em DynamoDB (projeto separado, `infra/backend/`).

```
                         Internet
                            │
                    Internet Gateway
┌─ VPC 10.0.0.0/16 ─────────┼────────────────────────────────────┐
│  ┌─ Sub-rede pública 10.0.1.0/24 (us-east-1a) ─┐                 │
│  │  EC2 t3.micro (Amazon Linux 2023)           │  SG ec2:        │
│  │  └─ container da API (porta 80 → 3000)      │  80 ← internet  │
│  └─────────────────────┬───────────────────────┘  22 ← meu IP/32 │
│                        │ 5432 (TLS com certificado verificado)   │
│  ┌─ Privada 10.0.11.0/24 (1a) ─┐  ┌─ Privada 10.0.12.0/24 (1b) ─┐ │
│  │  RDS PostgreSQL 17          │  │  (exigência do subnet group) │ │
│  └─────────────────────────────┘  └─────────────────────────────┘ │
│                                        SG rds: 5432 ← SG ec2    │
└───────────────────────────────────────────────────────────────────┘
State: S3 (versionado, criptografado, privado) + DynamoDB (lock)
```

- **EC2:** no primeiro boot, o `user_data` instala o Docker, clona o repositório, faz o build com o mesmo `app/Dockerfile` do ambiente local e sobe o container com `--restart unless-stopped`, sistema de arquivos somente leitura e sem capabilities.
- **RDS:** PostgreSQL 17 (a mesma versão do Compose), `db.t3.micro`, disco criptografado, sem Multi-AZ.
- **Proteções adicionais:** IMDSv2 obrigatório com hop limit 1 (os containers não alcançam os metadados da instância), discos criptografados e senha do banco em variável `sensitive`.

## Por que o RDS na sub-rede privada e a EC2 na pública

O que torna uma sub-rede pública é a rota `0.0.0.0/0 → Internet Gateway` na tabela de rotas dela.

- **EC2 na pública:** ela precisa **receber** requisições da internet (a API) e **sair** para a internet (instalar pacotes, clonar o repositório, baixar imagens Docker).
- **RDS na privada:** o banco só precisa ser acessado pela API. Na sub-rede privada, sem rota para a internet e com `publicly_accessible = false`, ele não tem caminho de entrada nem de saída. É defesa em profundidade, em três camadas: sem rota, sem IP público e SG que aceita a porta 5432 **somente do SG da EC2**. O teste de conexão direta do meu computador ao endpoint na porta 5432 falhou, como esperado.
- As **duas** sub-redes privadas existem porque o RDS exige um DB subnet group em pelo menos 2 zonas de disponibilidade, mesmo sem Multi-AZ.

## LabRole / LabInstanceProfile

O Learner Lab não permite criar usuários, grupos ou roles IAM, então o projeto **não tem nenhum recurso `aws_iam_*`**.

- **O Terraform** rodou com as credenciais temporárias da role do próprio lab (`voclabs`), carregadas como variáveis de ambiente.
- **A EC2 não recebeu instance profile.** Avaliei o uso do `LabInstanceProfile` e concluí que ele não era necessário: a instância não chama nenhuma API da AWS. Ela só clona um repositório público, baixa o certificado público do RDS e se conecta ao banco por usuário e senha. Aplicar uma role sem necessidade daria permissões a mais à instância, o que contraria o princípio do menor privilégio.
- **Onde ele seria usado:** numa evolução com a senha no SSM Parameter Store ou no Secrets Manager (em vez de no `user_data`), a EC2 precisaria ler esse segredo. Aí bastaria `iam_instance_profile = "LabInstanceProfile"` no módulo `ec2`, reaproveitando a role do lab em vez de criar uma.

## Ajustes exigidos pelo Learner Lab

| Restrição do lab | Ajuste feito |
|---|---|
| **Credenciais temporárias** (Access Key + Secret + Session Token, com ~4 h de validade) | Credenciais só em variáveis de ambiente, num arquivo local ignorado pelo Git (`chmod 600`), recarregado a cada sessão. Nada no código. A sessão expirou durante os testes e o fluxo de retomada foi documentado. |
| **Região fixa** (`us-east-1`) | Região em variável com esse padrão; as AZs são descobertas via `data "aws_availability_zones"`. |
| **Sem IAM** | Nenhum recurso IAM (ver acima). SSH com o par de chaves pré-existente do lab (`vockey`). |
| **SCP da organização bloqueando `s3:GetBucketObjectLockConfiguration`** | O recurso `aws_s3_bucket` falhava sempre, porque o provider lê essa configuração depois de criar o bucket. Solução: o bucket passou a ser criado por um script do AWS CLI (`criar-bucket.sh`), e as configurações dele (versionamento, criptografia, bloqueio público, ownership) e a tabela DynamoDB continuaram no Terraform. Desvio registrado na spec. |
| **EC2 parada ao fim da sessão** | Docker habilitado no boot + `--restart unless-stopped`: a API volta sozinha. Testado ao reiniciar o lab, com os dados preservados no RDS. O IP público muda, e o state é atualizado com `terraform apply -refresh-only`. |
| **Orçamento de 50 créditos** | `t3.micro` e `db.t3.micro`, sem NAT Gateway, sem Multi-AZ, backup mínimo e `terraform destroy` ao final, incluindo o bucket versionado, esvaziado manualmente. |
| **Classes de instância limitadas** | Uso das menores classes permitidas. |

Um ponto que **não** é do lab, mas apareceu no processo: o parâmetro `dynamodb_table` do backend S3 está obsoleto desde o Terraform 1.11 (a recomendação atual é `use_lockfile`). Mantive o DynamoDB por exigência do projeto; na versão 1.16.4 ele gera apenas um aviso.

# Questão 4 — Validação e Responsabilidade

Que checklist você aplicou antes de rodar terraform apply em código gerado por IA? Como validou que a infraestrutura estava correta e segura? O que aconteceria se você aceitasse o código da IA sem revisar? Como a evolução Git → Docker → Terraform → Modules preparou você para usar IA com responsabilidade?

## Respostas:

O checklist aplicado está descrito passo a passo no arquivo 'tasks.md'.

A infraestrutura foi validada juntando um mix de informações, sendo elas: pesquisas em fontes externas (documentações, e outras ferramentas de IA além da que eu utilizei como primária no projeto), testes práticos e análise de coerência nas informações passadas pela IA.

Por experiência própria, caso tivesse aceitando por completo (sem correções) o código passado por IA, teria diversos problemas principalmente no quesito de aplicação da infraestrutura na nuvem aws - diversos erros sem explicação rápida, IA não conseguindo se auto-corrigir, necessidade de correção manual de todo aquele código já feito anteriormente, além de possíveis problemas com vazamento de dados e informações.

Construir uma base sólida desde os primeiros passos facilita os passos futuros, evitando perda de tempo e tokens de forma desnecessárias. Além de contribuir grandemente com todo o entendimento técnico do projeto como em si, dando a você, enquanto desenvolvedor a capacidade de falar e debater com propriedade sobre tudo o que está sendo feito, seja com uma ferramenta de IA, com o cliente, ou com um chefe ou colega de equipe. 
