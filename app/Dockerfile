# =============================================================================
# Dockerfile da API de Reservas (Node.js/Express)
# -----------------------------------------------------------------------------
# Este arquivo é a "receita" para construir a IMAGEM da API. Cada instrução
# abaixo gera uma CAMADA (layer) da imagem. O Docker guarda essas camadas em
# cache: se uma instrução e tudo o que vem antes dela não mudaram, a camada é
# reaproveitada no próximo build, o que deixa os builds bem mais rápidos.
#
# Observação: o PostgreSQL NÃO é construído aqui. Ele usa a imagem oficial
# "postgres" direto no docker-compose.yml, que é também onde fica o volume
# persistente do banco.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Imagem base
# -----------------------------------------------------------------------------
# - node:24      -> Node.js 24, a versão LTS (suporte de longo prazo).
# - alpine       -> distribuição Linux mínima (~5 MB). Menos pacotes instalados
#                   significa uma imagem menor e MENOS SUPERFÍCIE DE ATAQUE
#                   (menos programas que podem ter vulnerabilidades).
# Usar uma tag fixa ("24-alpine") em vez de "latest" evita que o build mude
# de comportamento sozinho quando sair uma nova versão maior do Node.
FROM node:24-alpine

# -----------------------------------------------------------------------------
# 2. Variáveis de ambiente da imagem
# -----------------------------------------------------------------------------
# NODE_ENV=production faz o Express e várias bibliotecas ativarem otimizações
# e, entre outras coisas, esconder detalhes internos em mensagens de erro.
ENV NODE_ENV=production

# -----------------------------------------------------------------------------
# 3. Diretório de trabalho
# -----------------------------------------------------------------------------
# Todas as instruções seguintes (COPY, RUN, CMD) passam a rodar dentro de /app.
# Se a pasta não existir, o Docker a cria.
WORKDIR /app

# -----------------------------------------------------------------------------
# 4. Instalação das dependências (aproveitando o cache de camadas)
# -----------------------------------------------------------------------------
# Copiamos SÓ os arquivos de dependências primeiro, antes do código-fonte.
# Motivo: o código muda muito mais do que as dependências. Assim, alterar um
# arquivo em src/ NÃO invalida o cache desta etapa, e o "npm ci" (que é lento)
# só roda de novo quando o package.json ou o package-lock.json mudarem.
COPY package.json package-lock.json ./

# npm ci         -> instala EXATAMENTE as versões travadas no package-lock.json
#                   (o "npm install" poderia atualizar versões). Isso garante
#                   builds reproduzíveis e protege contra uma versão nova e
#                   maliciosa de algum pacote entrar sem você perceber.
# --omit=dev     -> não instala as devDependencies, que não são usadas em
#                   produção.
# npm cache clean -> apaga o cache de downloads do npm, que só ocuparia espaço
#                   na imagem final.
RUN npm ci --omit=dev && npm cache clean --force

# -----------------------------------------------------------------------------
# 5. Código-fonte da aplicação
# -----------------------------------------------------------------------------
# Copiamos só a pasta src/, de forma explícita, em vez de "COPY . .".
# Isso evita que arquivos sensíveis (ex.: um .env esquecido na pasta) acabem
# dentro da imagem. O .dockerignore vai reforçar essa proteção.
#
# Os arquivos ficam com dono "root" (o padrão do COPY). Como a aplicação vai
# rodar com o usuário "node" (passo 6), ela consegue LER o código, mas não
# consegue ALTERÁ-LO. Se um atacante explorar alguma falha da API, não
# conseguirá modificar o código da aplicação.
COPY src/ ./src/

# -----------------------------------------------------------------------------
# 6. Usuário sem privilégios
# -----------------------------------------------------------------------------
# Por padrão, containers rodam como root. Se alguém explorar uma falha na API,
# teria privilégios de root dentro do container, o que facilita escapar para
# o host ou causar mais estrago. A imagem oficial do Node já traz um usuário
# comum chamado "node" (UID 1000); aqui passamos a usá-lo.
USER node

# -----------------------------------------------------------------------------
# 7. Porta da aplicação
# -----------------------------------------------------------------------------
# EXPOSE é DOCUMENTAÇÃO: informa que a API escuta na porta 3000 dentro do
# container. Ele NÃO publica a porta no host; quem faz isso é o "ports:" do
# docker-compose.yml (ou o "-p" do docker run).
EXPOSE 3000

# -----------------------------------------------------------------------------
# 8. Comando de inicialização
# -----------------------------------------------------------------------------
# Usamos a "exec form" (formato de lista JSON) e chamamos o "node" diretamente:
# - exec form: o processo node vira o PID 1 do container, sem um shell (/bin/sh)
#   no meio. Assim ele recebe diretamente o sinal SIGTERM enviado pelo
#   "docker stop" e pode encerrar de forma limpa (fechar conexões com o banco).
# - "node" em vez de "npm start": o npm não repassa bem os sinais para o
#   processo filho, o que faria o container demorar ~10s para parar e depois
#   ser morto à força (SIGKILL).
CMD ["node", "src/server.js"]
