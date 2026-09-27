# Histórico de Prompts: API de Reservas (TechNova)

Registro de todos os prompts enviados à ferramenta de IA durante o desenvolvimento do projeto, na ordem em que foram usados.

- **Ferramenta:** Claude Code (modelo Claude Opus 5.5), usada como copiloto no terminal
- **Data da sessão:** 26/09/2026
- **Observação:** os prompts estão transcritos **exatamente como foram enviados**, incluindo erros de digitação, para preservar a fidelidade do registro. Abaixo de cada prompt há um breve resumo do resultado, para dar contexto.
- **Mascaramento:** as saídas de terminal coladas nos prompts (logs, mensagens de erro, resultados de comandos), assim como resultados, comandos e URLs digitados no meio do texto, foram substituídos por "Dados mascarados por segurança.", porque continham ou poderiam conter dados da conta AWS, da máquina e do usuário. O restante do texto escrito pelo desenvolvedor foi mantido.

---

## Etapa 1: Contexto e estrutura do projeto

### Prompt 1
> Bom dia Claude.

**Resultado:** saudação inicial; a IA identificou o repositório e o estado do Git.

### Prompt 2
> Estamos em um ambiente de desenvolvimento onde precisamos entregar uma infraestrutura pronta e funcionando. Coloquei algumas informações em 'contextoDoProjeto.md', quero que somente leia esse arquivo para entender no que vamos trabalhar. Entenda também a estrutura de pastas que criei e verifique se está de acordo com a estrutura solicitada pelo cliente - isso está mencionado em '#Estrutura do projeto' no arquivo 'contextoDoProjeto.md'.

**Resultado:** leitura do arquivo de contexto e resumo do projeto. A IA pediu autorização para listar as pastas do projeto.

### Prompt 3
> sim, rode.

**Resultado:** listagem das pastas. Foi identificada a falta de `infra/backend/` e explicado que o Git não versiona pastas vazias.

### Prompt 4
> já criei a pasta 'backend/' dá uma conferida. Confira tambem o '.gitignore' novamente.

**Resultado:** análise do `.gitignore`, com sugestões (`.env.*` + `!.env.example`, arquivos de plan do Terraform). A IA pediu autorização para verificar a pasta e os arquivos rastreados pelo Git.

### Prompt 5
> sim, rode.

**Resultado:** confirmado que `infra/backend/` existe no local correto e que `contextoDoProjeto.md` nunca foi commitado.

### Prompt 6
> fiz manualmente algumaas correções, vamos fazer o restante conforme o andar do projeto.

**Resultado:** a IA propôs começar pela aplicação e perguntou se o banco seria usado desde o início.

### Prompt 7
> Vamos fazer com PostgreSQL desde o início.

**Resultado:** plano da aplicação (estrutura de arquivos, dependências `express` e `pg`, tabela, rotas e medidas de segurança).

---

## Etapa 2: Containerização da aplicação

### Prompt 8
> Sim, estou de acordo, porém sempre vamos por partes. Vamos começar trabalhando primeiramente no arquivo 'Dockerfile' que deve ser criado em /app. Pontos importantes: 1. O banco de dados escolhido é PostgreSQL. | 2. O dockerfile do banco deve ter volumes persistenes, ou seja, mesmo depois do container e da aplicação ser derrubada os dados devem permanecer intactos.

**Resultado:** criação do `app/Dockerfile`. A IA explicou que o PostgreSQL usa a imagem oficial (sem Dockerfile próprio) e que a persistência será feita com um volume nomeado no `docker-compose.yml`.

### Prompt 9
> Fiz a movimentação do arquivo 'Dockerfile' para /app/src - havia me enganado no caminho passado anteriormente, o correto é /app/src. Vamos em seguida para '.dockerignore'.

**Resultado:** a IA apontou que a estrutura do cliente prevê o Dockerfile em `app/` e que a mudança quebraria o contexto de build.

### Prompt 10
> Tem razão, o movi de volta para /app manualmente.

**Resultado:** criação do `app/.dockerignore` no modelo de lista de permissões (allowlist).

### Prompt 11
> Sim, seguimos com ele.

**Resultado:** criação do `app/package.json` e apresentação das opções para gerar o `package-lock.json`.

### Prompt 12
> Vou com a opção A, instalar o node em minha máquina. pode me mostrar o comando que instalo manualmente.

**Resultado:** instruções de instalação do Node.js via `dnf` (Fedora).

### Prompt 13
> Na verdade, vamos fazer uma alteração. Vamos seguir com o passo B: Via Docker, sem instalar Node no sistema. pode me mostrar como?

**Resultado:** comando `docker run` para gerar o `package-lock.json` num container descartável, com a explicação de cada parâmetro.

### Prompt 14
> Executar o docker build sem esse passo antes não dará certo?

**Resultado:** a IA explicou por que o build falharia sem o lock (`COPY` e `npm ci`).

### Prompt 15
> ok, executei conforme me instruiu, recebi este erro:
>
> Dados mascarados por segurança.

**Resultado:** diagnóstico do erro de permissão (`EACCES`) e sugestão de comandos de verificação.

### Prompt 16
> segue a saída de cada comando:
>
> Dados mascarados por segurança.

**Resultado:** identificada a causa provável: o comando foi executado fora da raiz do projeto, e o Docker criou uma pasta vazia com dono root. A IA recomendou usar `--mount` em vez de `-v`.

### Prompt 17
> a execução deve ser na raiz do projeto?

**Resultado:** explicação de como o `$PWD` é resolvido e versão do comando usando `--mount`.

### Prompt 18
> ok, agora recebi essa mensagem:
>
> Dados mascarados por segurança.

**Resultado:** `package-lock.json` gerado com sucesso. A IA explicou a saída e recomendou não atualizar o npm.

---

## Etapa 3: Código da aplicação

### Prompt 19
> 1. Essa pasta não existe, foi erro meu. Sobre o próximo passo: Sim, vamos para o db.js

**Resultado:** criação do `app/src/db.js` (pool de conexões, SSL, tipo DATE e criação da tabela).

### Prompt 20
> Não, até então nenhuma dúvida. Vamos para validacao.js.

**Resultado:** criação do `app/src/validacao.js` (validação dos campos e do id).

### Prompt 21
> Vamos manter o status obrigatório no POST. Vamos para o próximo passo: routes/reservas.js.

**Resultado:** criação do `app/src/routes/reservas.js` (CRUD com queries parametrizadas).

### Prompt 22
> Seguimos.

**Resultado:** criação do `app/src/app.js` (middlewares, `/health`, 404 e tratador de erros).

### Prompt 23
> Sim, vamos para o server.js.

**Resultado:** criação do `app/src/server.js` (inicialização com novas tentativas e encerramento limpo) e comando do `docker build` salvando a evidência.

---

## Etapa 4: Revisão de segurança antes do push

### Prompt 24
> já rodei o build, tudo ok. Quer que leia o arquivo 'docker-build.txt' dentro da pasta evidencias/. Existe algum dado sensível que pode ser vazado lá?

**Resultado:** a evidência do build foi revisada, sem dados sensíveis. A IA explicou o aviso `npm warn using --force`.

### Prompt 25
> Vamos manter como está, obrigado. Quero agora que avalie o meu .gitignore, logo mais vou dar um git push para subir para o github e preciso saber se está de acordo com o que fizemos até agora.

**Resultado:** avaliação do `.gitignore`, com sugestões (credenciais da AWS, plans do Terraform) e verificações a fazer antes do push.

### Prompt 26
> ok, vou fazer o git push. Até agora sem dados sensíveis.

**Resultado:** checklist para conferir o repositório no GitHub após o push.

### Prompt 27
> push feito. Antes de prosseguirmos, um dos requisitos do meu cliente e entregar a ele todo o histórico de prompts que usitlizei para desenvolver o sistema. Pode criar pra mim dentro da raiz do projeto um arquivo nomeado "historico_de_prompts.md" com todos os prompts utilizados até agora?

**Resultado:** criação deste arquivo.

### Prompt 28
> 1. Não vamos incluir minhas decisões e configurações pessoais. | 2. Sim, por favor, para este projeto em específico, faça a atualização do histórico com os prompts usados.

**Resultado:** decidido que as configurações pessoais da ferramenta ficam fora do histórico e que este arquivo será atualizado a cada novo prompt.

### Prompt 29
> Sim, pode salvar na sua memória. E vamos fazer uma pausa, em breve retornamos ao projeto.

**Resultado:** a regra de atualização deste histórico foi salva na memória da ferramenta, para valer nas próximas sessões. Pausa no desenvolvimento; a próxima etapa é o `docker-compose.yml`.

---

## Etapa 5: Retomada e orquestração com Docker Compose

### Prompt 30
> Boa tarde Claude, vamos seguir nossa sessão de trabalho?

**Resultado:** retomada da sessão. A IA revisou o estado do `.gitignore` e propôs seguir com o `docker-compose.yml`.

### Prompt 31
> Vou manter o histórico de prompts fora do github por enquanto, envio ele na data correta. Vamos para o próximo passo, criar o docker-compse.yml. Sim ele vai na raiz do projeto, pode criá-lo?

**Resultado:** criação do `docker-compose.yml` (PostgreSQL com volume nomeado e healthcheck, API com `depends_on` no banco saudável, redes separadas, porta publicada só em `127.0.0.1` e hardening do container da API).

### Prompt 32
> Siga com .env.example

**Resultado:** criação do `.env.example` (modelo das variáveis, com a senha propositalmente vazia) e instruções para criar o `.env` real manualmente.

### Prompt 33
> .env pronto. vamos seguir testando o comando docker compose up, me mostre os comandos.

**Resultado:** sequência de comandos para validar o `docker-compose.yml`, subir o ambiente, testar a API, testar a persistência dos dados e gerar a evidência `compose-ps.txt`.

### Prompt 34
> ok, fiz todos os teste aqui, tudo certo. os dados inseridos via curl se mantiveram mesmo após a derrubada do banco com docker compose down.

**Resultado:** ambiente local validado (API e banco saudáveis, dados persistidos após o `docker compose down`). A IA notou que a evidência `compose-ps.txt` ainda não havia sido gerada e sugeriu o commit desta etapa.

### Prompt 35
> ok, confira o arquivo na pasta evidencias.

**Resultado:** a IA revisou `compose-ps.txt` (os dois serviços `healthy`, banco sem porta publicada no host, API restrita a `127.0.0.1`) e `docker-build.txt` (sem dados sensíveis).

---

## Etapa 6: Infraestrutura como código (Terraform)

### Prompt 36
> Próximo passo vamos estruturar o terraform. Antes de tudo, gostaria de saber se podemos seguir o método spec-driven a partir daqui?

**Resultado:** a IA explicou o desenvolvimento orientado a especificação (spec-driven), propôs um formato leve com três documentos (requisitos, design e tarefas) e pediu decisões sobre onde guardar a spec e se ela entra no Git.

### Prompt 37
> 1. Vamos com a opção (b) = infra/specs/ - durante o processo vou tomar a decisão de subir ou não as specs no github. | 2. OK. | 3. Estou utilizando atualmente uma conta de estudante na AWS (Leaner Lab) e infelizmente ela não permite usuários IAM. Nossa região obrigatória será a padrão apresentada pelo learner lab.

**Resultado:** criação do `infra/specs/requirements.md`, com os requisitos da infraestrutura, as restrições do AWS Academy Learner Lab e as questões em aberto a validar antes do design.

### Prompt 38
> 1. Documento revisado - revisei o segundo tópico (2. Restrições do ambiente (AWS Academy Learner Lab) e apaguei os ícones de aviso, pois os pontos foram verificados como verdadeiros, então os mantive como estão. | 2. Q-01: Vamos com a opção (a). / Q-02: SSH com a chave vockey. / Q-03: Via variável sensitive. | Q-04: Usamos só DynamoDB. | Q-05: A versão que estou usando do terraform é a v1.16.4.

**Resultado:** requisitos aprovados, com as questões em aberto registradas como decisões. Criação do `infra/specs/design.md` (arquitetura, módulos, interfaces entre eles, `user_data` e decisões de design).

### Prompt 39
> Decisões: a) vamos seguir com o backend.hcl | b) OK, vamos dar sequência com o IMDSv2 com hop limit 1. | c) OK. | d) OK, vamos verificar nos testes.

**Resultado:** design aprovado. Criação do `infra/specs/tasks.md`, com as tarefas de implementação em ordem, cada uma ligada aos requisitos e com a forma de verificação.

### Prompt 40
> pendências: 1. Sim, o github é público. | 2. Sim, nós temos um orçamento de 50 créditos disponíveis para usarmos durante a fase de implementação e testes. | 3. O AWS Cli está instalado.    Não comece nenhuma execução das tasks ainda, irei revisar.

**Resultado:** a restrição R-04 foi atualizada no `requirements.md` com o orçamento confirmado (50 créditos). Nenhuma tarefa foi iniciada; o `tasks.md` aguarda a revisão do desenvolvedor.

### Prompt 41
> Falando sobre o 'tasks.md': T-02: Utilizarei variáveis de ambiente durante esses testes - criei em nosso projeto um arquivo chamado "aws-credentials.sh" com as credenciais do Lab para testes - dessa forma sempre que o lab expirar - carregarei novamente de forma manual.

**Resultado:** a IA apontou que o arquivo de credenciais dentro de um repositório público não estava coberto pelo `.gitignore`, recomendou mantê-lo fora do projeto ou protegê-lo, e atualizou as tarefas T-01 e T-02 do `tasks.md`.

### Prompt 42
> Verifiquei os status de log do git - não tem nenhum commit contendo essas credenciais. Sobre o chmod recomendado - também já executei o chmod 600.

**Resultado:** confirmado que as credenciais nunca foram commitadas e que o arquivo está protegido com `chmod 600`. A IA perguntou se adiciona desde já a regra do `aws-credentials.sh` no `.gitignore`.

### Prompt 43
> OK, adicione no gitignore.

**Resultado:** a IA verificou que a regra `aws-credentials.sh` já estava no `.gitignore`, sem necessidade de alteração, e indicou o comando para confirmar que ela funciona.

### Prompt 44
> OK, vamos prosseguir com a fase A das tasks.

**Resultado:** T-01 concluída (regras `backend.hcl` e `*.tfplan` no `.gitignore`). Para a T-02 e a T-03, a IA passou os comandos de verificação das credenciais e de descoberta do IP público, a serem executados pelo desenvolvedor.

### Prompt 45
> deu tudo certo, T-02 e T-03 foram executados por mim - já estou com as credenciais carregadas e com o IP público anotado. Uma dúvida sobre o IP público: Ele é o IP da minha máquina local? Corro algum risco de segurança?

**Resultado:** Fase A concluída. A IA explicou a diferença entre IP público e IP local (NAT e CGNAT), os riscos reais de expor o IP público e por que a regra de SSH com `/32` continua segura.

### Prompt 46
> OK, vamos para a fase B.

**Resultado:** criação dos arquivos da T-04 em `infra/backend/` (`providers.tf`, `variables.tf`, `main.tf` e `outputs.tf`), com o bucket S3 versionado, criptografado e privado e a tabela DynamoDB do lock. A IA passou os comandos de `fmt`, `init`, `validate`, `plan` e `apply`, a serem executados pelo desenvolvedor.

### Prompt 47
> executei todos em ordem. Como eu esperava, tive problemas no terraform apply, o erro foi o seguinte:
>
> Dados mascarados por segurança.

**Resultado:** diagnóstico do erro: o bucket foi criado, mas a leitura da configuração de Object Lock, feita automaticamente pelo provider, é bloqueada por uma Service Control Policy (SCP) do Learner Lab. A IA pediu o `terraform state list` para confirmar o estado parcial e propôs alternativas, que exigem revisar o design.

### Prompt 48
> desativar o getObjectLock não resolveria?

**Resultado:** a IA explicou que o Object Lock já está desativado no bucket, e que o problema é a chamada de leitura (`GetObjectLockConfiguration`) que o provider sempre faz, bloqueada pela SCP independentemente da configuração do bucket.

### Prompt 49
> ok, vamos de opção a.

**Resultado:** o desvio foi registrado na spec (`design.md` §4, tarefas T-04 e T-13). O `main.tf` do backend deixou de usar o recurso `aws_s3_bucket` e passou a referenciar o bucket pelo nome, e foi criado o script `infra/backend/criar-bucket.sh` (AWS CLI, idempotente). A IA passou os comandos para limpar o state e aplicar de novo.

### Prompt 50
> o terraform apply foi bem sucedido. A verificação de versionamento também retornou como Dados mascarados por segurança.

**Resultado:** T-04 concluída (Fase B). A IA sugeriu o commit do backend e os cuidados com o state local.

### Prompt 51
> Vamos para a fase 4.

**Resultado:** a IA pediu confirmação de qual fase seguir, já que as fases do `tasks.md` são identificadas por letras (A a E) e a Fase D depende da Fase C, que ainda não foi feita.

### Prompt 52
> Desculpe, escrevi errado. Vamos para a fase C.

**Resultado:** criação dos arquivos da T-05: `infra/providers.tf` (versões, backend S3 com configuração parcial e provider com `default_tags`), `infra/variables.tf` (só `aws_region` por enquanto) e `infra/backend.hcl.example`. A IA passou os comandos para gerar o `backend.hcl` e rodar o `terraform init`.

### Prompt 53
> Paramos no passo 2. Vamos trabalhar em cima dele antes de prosseguir para o 3. Conforme esperamos deu erro, segue: terraform init -backend-config=backend.hc

**Resultado:** a mensagem de erro não veio junto com o prompt. A IA notou que o comando enviado tem o nome do arquivo incompleto (`backend.hc` em vez de `backend.hcl`), o que por si só causaria um erro, e pediu a mensagem de erro completa.

### Prompt 54
> Segue o erro correto, digitei errado:
>
> Dados mascarados por segurança.

**Resultado:** a IA separou as duas mensagens: o aviso confirmou que o `dynamodb_table` funciona na 1.16.4 (risco d) resolvido), e o erro mostrou que o `backend.hcl` ainda tinha o marcador `<NOME_DO_BUCKET>` no lugar do nome real do bucket. Foram passados os comandos para regenerar o arquivo e repetir o `init`.

### Prompt 55
> Agora sim, realmente tinha sido um erro na sintaxe do comando que escrevi. O resultado do terraform init foi um sucesso, o erro apareceu mas foi executado corretamente. Vamos continuar com o passo 3.

**Resultado:** `init` com backend remoto concluído. A IA explicou a diferença entre aviso e erro e passou os comandos do passo 3 (`fmt`, `validate`) e a verificação de que não existe state local.

### Prompt 56
> Sim, os 3 foram conforme o esperado. Vamos seguir.

**Resultado:** T-05 concluída. Criação dos arquivos da T-06: módulo `infra/modules/vpc/` (VPC, Internet Gateway, sub-rede pública com rota para a internet e 2 sub-redes privadas em AZs diferentes, sem rota) e `infra/main.tf` com a chamada ao módulo. A IA passou os comandos de `init`, `validate` e `plan`.

### Prompt 57
> Segue o resultado do plan (subnets pública e privada):
>
> Dados mascarados por segurança.

**Resultado:** a IA analisou as duas sub-redes (pública em `us-east-1a` com IP público automático; privada 2 em `us-east-1b`, sem IP público; tags padrão aplicadas) e pediu o trecho da `privada[0]` e a linha de resumo do plan para fechar a verificação da T-06.

### Prompt 58
> 1. Segue:
>
> Dados mascarados por segurança.
>
> | 2. Segue: Dados mascarados por segurança. | 3. O resultado foi conforme o esperado.

**Resultado:** T-06 concluída: as 2 sub-redes privadas estão em AZs diferentes (`us-east-1a` e `us-east-1b`), o plan tem 10 recursos a criar e a tabela de rotas privada não tem rota para a internet. A IA sugeriu o commit do módulo `vpc`.

### Prompt 59
> Sim, seguimos.

**Resultado:** criação dos arquivos da T-07: módulo `infra/modules/security-group/` (SG da EC2 com HTTP e SSH restrito, SG do RDS liberando a 5432 só a partir do SG da EC2, validações do `cidr_ssh`), chamada no `infra/main.tf`, variáveis `cidr_ssh`/`cidr_http` e o modelo `infra/terraform.tfvars.example`. A IA passou os comandos para criar o `terraform.tfvars`, rodar o plan e fazer o teste negativo.

### Prompt 60
> O resultado de ambos os teste negativos foram "cidr_ssh é amplo demais". O resultado do terraform plan após a execução desses dois testes negativos foi de: Dados mascarados por segurança.

**Resultado:** testes negativos aprovados. A IA apontou uma divergência entre os 15 recursos do plan e os 16 esperados, e passou um comando para listar os recursos planejados e descobrir qual está faltando antes de concluir a T-07.

### Prompt 61
> Resultado:
>
> Dados mascarados por segurança.

**Resultado:** a lista tem os 16 recursos esperados, todos presentes. A divergência veio da leitura do resumo, e não do código. A IA pediu para confirmar a linha de resumo e concluiu a T-07.

### Prompt 62
> Pode seguir.

**Resultado:** criação dos arquivos da T-08: módulo `infra/modules/rds/` (DB subnet group e instância PostgreSQL 17 criptografada, sem acesso público), chamada no `infra/main.tf`, variável `db_senha` (sensitive, com validações) e a linha de modelo no `terraform.tfvars.example`. A IA passou o comando para gerar a senha localmente e acrescentá-la ao `terraform.tfvars`, sem que ela passe pela conversa.

### Prompt 63
> No terraform plan, me deparei com este erro:
>
> Dados mascarados por segurança.

**Resultado:** a IA explicou que o lock do DynamoDB funcionou como previsto (CA-01.3): um plan anterior, interrompido ou ainda em execução, deixou o lock preso. Foram passados os comandos para verificar se há outro processo do Terraform rodando e, se não houver, liberar o lock com `terraform force-unlock`.

### Prompt 64
> Ok, terraform plan executado.w

**Resultado:** lock liberado e plan executado. A IA pediu a saída do filtro (resumo e atributos de segurança do RDS) para concluir a verificação da T-08.

### Prompt 65
> Dados mascarados por segurança.

**Resultado:** T-08 concluída: senha oculta no plan, banco sem acesso público, armazenamento criptografado, PostgreSQL 17 e 18 recursos a criar. A IA explicou o atributo `password_wo` (write-only) como possível melhoria futura e sugeriu o commit do módulo `rds`.

### Prompt 66
> Segue a URL: Dados mascarados por segurança.

**Resultado:** criação dos arquivos da T-09: módulo `infra/modules/ec2/` (AMI Amazon Linux 2023, instância com IMDSv2 e hop limit 1, disco criptografado, chave `vockey`) e o script `user_data.sh.tftpl` (Docker, certificado do RDS, clone, build e container com as mesmas proteções do Compose). Chamada no `infra/main.tf` e variável `url_repositorio`, com a URL do repositório como valor padrão.

### Prompt 67
> Plan foi bem sucedido.

**Resultado:** o plan da T-09 rodou sem erros, o que confirma que o template do `user_data` está bem formado. A IA pediu a saída do filtro para conferir os itens de segurança (IMDSv2, disco criptografado e `user_data` oculto) antes de concluir a tarefa.

### Prompt 68
> ;Segue:
>
> Dados mascarados por segurança.

**Resultado:** T-09 concluída: `user_data` oculto no plan, IMDSv2 obrigatório com hop limit 1, disco da EC2 criptografado, chave `vockey` e 19 recursos a criar. A IA sugeriu o commit do módulo `ec2` e apresentou o que falta na T-10.

### Prompt 69
> Sim, pode seguir.

**Resultado:** criação do `infra/outputs.tf` (URL do health check, IP público da EC2, comando SSH e endpoint do RDS, sem nenhuma saída sensível). A IA passou os comandos da verificação final da Fase C (`fmt`, `validate` e `plan`).

---

## Etapa 7: Evidência, aplicação e testes na AWS

### Prompt 70
> Saiu como esperado, vamos prosseguir.

**Resultado:** T-10 e Fase C concluídas. Início da T-11: a IA passou os comandos para salvar o plan em arquivo, gerar a evidência `terraform-plan.txt` a partir dele e anonimizar o IP do desenvolvedor, que aparece na regra de SSH.

### Prompt 71
> Ok, executei os comandos mencionados manualmente, os resultados foram conforme o esperado. Porém mesmo assim quero que revise o arquivo de evidência para garantir que nenhum dado sensível foi exposto.

**Resultado:** a IA leu as 544 linhas do `evidencias/terraform-plan.txt` e não encontrou dados sensíveis: senha e `user_data` ocultos, IP anonimizado, sem ID da conta, credenciais ou nome de bucket. T-11 concluída.

### Prompt 72
> Tudo OK, vamos seguir.

**Resultado:** início da T-12. A IA passou o comando do `terraform apply` com o plano salvo, o tempo esperado de criação e o primeiro teste de aceite (health check), além de como diagnosticar pelo SSH se a API não responder.

### Prompt 73
> Ok, o apply foi bem sucedido. Quais os próximos passos?

**Resultado:** infraestrutura criada na AWS (19 recursos). A IA passou o roteiro completo dos testes de aceite da T-12: health check, CRUD, SSH, banco inacessível de fora, parar e religar a EC2 (persistência e retorno automático), lock e ausência de state local.

### Prompt 74
> Durante a execução do teste 3, me deparei com esse resultado:
>
> Dados mascarados por segurança.
>
>  - mascarei o sha256 por segurança

**Resultado:** a IA explicou as duas mensagens: a chave privada `labsuser.pem` não estava na pasta (é preciso baixá-la do Learner Lab e guardá-la fora do repositório, com `chmod 400`), e o aviso de autenticidade do host é o modelo TOFU do SSH. Foi indicado como conferir a impressão digital da chave do servidor pelo console da EC2 antes de aceitar.

### Prompt 75
> rodei este comando: Dados mascarados por segurança. - Estou com o terminal sobre a pergunta de 'yes/no' novamente.

**Resultado:** a IA orientou manter a pergunta aberta, conferir o fingerprint em um segundo terminal (via `get-console-output`) e só então responder `yes`, ou responder `no` se os valores forem diferentes.

### Prompt 76
> ok, comparei e são de fato iguais, digitei yes. Podemos retomar os teste daí?

**Resultado:** Teste 3 (SSH) aprovado, com o fingerprint verificado. A IA sugeriu aproveitar a sessão SSH para conferir o container e o log do `user_data`, e retomou o roteiro a partir do Teste 4.

### Prompt 77
> Um ponto importante que notei agora: Continuo dentro de minha máquina local, com meus arquivos e repositórios. Era suposto eu estar em outra máquina?

**Resultado:** a IA explicou que, depois do `yes`, o terminal do SSH deveria mostrar o prompt da EC2 (`ec2-user@ip-10-0-1-x`), e que continuar na máquina local indica que a conexão falhou ou foi encerrada logo em seguida. Foram passados os comandos para identificar em qual máquina o terminal está e o que observar na saída do SSH.

### Prompt 78
> Recebi esta mensagem:
>
> Dados mascarados por segurança.

**Resultado:** a IA explicou que a chave do servidor foi aceita e gravada, mas o servidor encerrou a conexão na etapa de autenticação do usuário. Foram passados comandos para validar o arquivo `labsuser.pem` e rodar o SSH em modo verboso (`-v`), a fim de ver em que ponto a autenticação falha.

### Prompt 79
> Estou com o terminal congelado após este comando.

**Resultado:** a IA reconheceu um erro no comando que passou: o SSH interativo com a saída redirecionada para o `grep` fica esperando, sem mostrar o prompt remoto (se a conexão der certo, a sessão fica aberta, mas "invisível"). Foi indicado como sair (`exit` ou Ctrl+C) e passada uma versão não interativa do teste, que roda um único comando remoto e encerra.

### Prompt 80
> Ok, consegui sair. Segue o resultado do comando anterior:
>
> Dados mascarados por segurança.

**Resultado:** a IA identificou que o SSH só ofereceu uma chave pessoal do agente SSH (recusada pela EC2) e não o `labsuser.pem`. Foram passados comandos para conferir o arquivo da chave e repetir o teste com `IdentitiesOnly=yes`, que força o uso exclusivo do `labsuser.pem`.

### Prompt 81
> 1. Dados mascarados por segurança.
> 2. Dados mascarados por segurança.
> 3. ;
>
> Dados mascarados por segurança.

**Resultado:** Teste 3 (SSH) aprovado. A causa do problema foi a chave pessoal do ssh-agent, oferecida antes do `labsuser.pem`; com `IdentitiesOnly=yes`, a autenticação funcionou. A IA propôs ajustar o output `comando_ssh` e retomou o roteiro no Teste 4.

### Prompt 82
> Podemos voltar ao passo 3?

**Resultado:** a IA retomou o Teste 3 com uma sessão SSH interativa, agora com `IdentitiesOnly=yes`, e passou as verificações a fazer dentro da EC2 (container, log do `user_data` e permissões do `api.env`).

### Prompt 83
> Ok, agora consegui entrar dentro do ec2 e executar o 'docker ps'. Antes de seguirmos, as chaves da aws vão expirar. Vou reiniciar o lab e atualizar as credenciais no repo. Pode me instruir para retomarmos daí?

**Resultado:** acesso interativo à EC2 confirmado. A IA passou o roteiro de retomada após reiniciar o lab: atualizar e carregar as credenciais, verificar o estado da EC2 e do RDS (e ligá-los, se necessário), atualizar o IP no state com `apply -refresh-only` e reaproveitar a situação como o Teste 5 (a API deve voltar sozinha, com os dados preservados).

### Prompt 84
> ok, até aqui tudo conforme. Podemos seguir.

**Resultado:** lab reiniciado e Teste 5 aprovado: a API voltou sozinha e os dados foram preservados. A IA atualizou o checklist da T-12 no `tasks.md` e passou os testes restantes (4, 6 e 7).

### Prompt 85
> OK, tudo conforme. Seguimos.

**Resultado:** T-12 concluída: todos os testes de aceite aprovados (RDS inacessível de fora, CRUD completo com DELETE e 404, lock e ausência de state local). Fase D encerrada. A IA listou o que falta para a entrega antes da T-13 (destruição) e perguntou como tratar o custo dos recursos enquanto isso.

### Prompt 86
> OK, então vamos por partes. Antes de prosseguirmos com o destroy, preciso de uma coisa: dentro de nosso arquivo 'historico_de_prompts.md', quero que mascare todos os resultados do meu terminal que colei para você ver - mascare substituindo todo o resultado colado por mim por uma mensagem dizendo: "Dados mascarados por segurança."

**Resultado:** as saídas de terminal coladas em 15 prompts (15, 16, 18, 47, 54, 57, 58, 61, 63, 65, 68, 74, 78, 80 e 81) foram substituídas por "Dados mascarados por segurança.", e uma nota sobre o mascaramento foi adicionada ao cabeçalho do arquivo.

### Prompt 87
> Pode mascarar os que citou acima também, por segurança.

**Resultado:** também foram mascarados os resultados e comandos digitados no meio do texto dos prompts 50, 60, 66 e 75.

### Prompt 88
> faça a pendência 1 primeiro.

**Resultado:** a regra de mascaramento foi registrada na memória da ferramenta, junto com a regra de atualização deste histórico, para valer nas próximas sessões.

---

## Etapa 8: Encerramento da infraestrutura

### Prompt 89
> Agora, sobre pendência 2: Vamos de opção C - Quero aplicar o 'terraform destroy' - Detalhe: se lembra do s3 que havíamos deixado fora do controle do terraform? Preciso garantir que ele esteja desativado, sem consumir quaisquer créditos na aws.

**Resultado:** início da T-13. A IA passou o roteiro de destruição em ordem: `terraform destroy` do projeto principal, `terraform destroy` do backend, esvaziamento completo do bucket versionado (todas as versões e marcadores de exclusão), exclusão do bucket via AWS CLI e a verificação final de que nenhum recurso cobrável ficou para trás.

### Prompt 90
> OK, tudo foi conforme o esperado.

**Resultado:** T-13 concluída: infraestrutura principal, backend e bucket do state removidos, e a verificação final confirmou que nenhum recurso do projeto ficou na conta. A IA recomendou a limpeza local dos arquivos que ainda guardam dados sensíveis (planos salvos, `terraform.tfvars` e a entrada do `known_hosts`).

### Prompt 91
> Antes, existe algum problema em versionar a pasta spec com os arquivos?

**Resultado:** a IA revisou o conteúdo dos três arquivos da spec em busca de dados sensíveis (nenhum encontrado) e explicou os prós e os pontos de atenção de publicá-los, principalmente a seção de riscos conhecidos do design.

### Prompt 92
> Já fiz o commit manualmente. Tem algo pendente em relação ao código e infra estrutura a ser feito? Seja objetivo.

**Resultado:** a IA listou as pendências de código e infraestrutura: status do `tasks.md`, ajuste opcional do output `comando_ssh`, conferência de commits pendentes com `git status` e limpeza local dos `.tfplan`.

### Prompt 93
> Nenhum deles por agora. Sobre os arquivos que citou para excluir por segurança antes: Não irei excluir, para fins acadêmicos e de estudo futuro, prefiro manter guardado para futuras pesquisas. Como se trata de um ambiente que não será exposto, imagino não ter problema.

**Resultado:** a IA concordou que o risco é baixo, já que os recursos foram destruídos e os arquivos estão ignorados pelo Git, e listou os cuidados para mantê-los com segurança.

---

## Etapa 9: Relatório

### Prompt 94
> O arquivo README.md já está pronto, as informações contidas nele são o necessário. Vamos ao "relatorio.md" - prefio fazer a maior parte manualmente, porém algumas coisas pedirei a você, vamos começar por: Responda de forma objetiva a Questão 3 - Infraestrutura, Segurança e o Learner Lab.

**Resultado:** a resposta da Questão 3 foi escrita no `relatorio.md`: diagrama da arquitetura, motivo de o RDS ficar na sub-rede privada e a EC2 na pública, uso (e não uso) do LabRole/LabInstanceProfile, e uma tabela com os ajustes exigidos pelo Learner Lab.

### Prompt 95
>  Pode revisar meu gitignore para ver se falta algo?

**Resultado:** a IA revisou o `.gitignore`, apontou que a regra do `contextoDoProjeto.md` foi removida (e perguntou se foi intencional) e sugeriu regras que faltavam: logs de erro do Terraform, `*.tfvars.json`, configuração da CLI do Terraform, chave `.ppk` e arquivos de sistema e de editor.

### Prompt 96
> Fiz a adição de algumas, por favor revise.

**Resultado:** a IA revisou as regras novas e apontou que `.tfvars.json` estava sem o `*` (casaria só com um arquivo com esse nome exato) e que as regras dos logs de erro do Terraform (`crash.log`) ainda faltavam.

### Prompt 97
> ok, adicionado.

**Resultado:** a IA confirmou as regras `crash.log`/`crash.*.log` e o novo comentário, e apontou que a linha `.tfvars.json` continuava sem o `*`.

### Prompt 98
> Faça a validação se a estrutura do projeto bate com a que foi requisitada pelo cliente.

**Resultado:** a IA pediu autorização para rodar dois comandos somente leitura (`find` e `git ls-files`), explicando que é preciso comparar tanto a estrutura local quanto o que de fato será entregue pelo Git.

### Prompt 99
> Não. Pode revisar se ainda tem algum arquivo com dado sensível que não está no gitignore?

**Resultado:** sem rodar comandos, a IA cruzou os arquivos conhecidos do projeto com o `.gitignore` atual e releu os documentos de entrega (`historico_de_prompts.md`, `relatorio.md`, `README.md`). Nenhum arquivo com dado sensível ficou descoberto. A IA apontou a limitação da revisão (arquivos criados fora da sessão não aparecem sem uma listagem) e um erro no campo "Data" do `README.md`.

### Prompt 100
> Pode adicionar um breve resumo do projeto no 'README.md'.

**Resultado:** foi adicionada ao `README.md` a seção "Sobre o projeto", com a descrição da API e um resumo das partes entregues (aplicação, ambiente local, infraestrutura AWS, spec, evidências, relatório e histórico).
