// =============================================================================
// db.js: conexão com o PostgreSQL
// -----------------------------------------------------------------------------
// Responsabilidades deste módulo:
//   1. Ler a configuração do banco a partir de VARIÁVEIS DE AMBIENTE.
//   2. Criar um POOL de conexões, compartilhado por toda a aplicação.
//   3. Criar a tabela "reservas" quando a API iniciar, se ela ainda não existir.
//
// Nenhuma credencial fica escrita neste arquivo. Os valores chegam por
// variáveis de ambiente, definidas pelo docker-compose.yml (via .env) no
// ambiente local e pela configuração da EC2 na AWS. Assim o mesmo código roda
// nos dois ambientes, e nenhuma senha vai parar no Git.
// =============================================================================

const fs = require('node:fs');
const { Pool, types } = require('pg');

// -----------------------------------------------------------------------------
// 1. Validação das variáveis de ambiente obrigatórias ("fail fast")
// -----------------------------------------------------------------------------
// Se faltar alguma variável, é melhor a API parar AGORA, com uma mensagem clara,
// do que subir "funcionando" e falhar só na primeira requisição, com um erro
// confuso de conexão.
//
// A mensagem mostra só os NOMES das variáveis que faltam, nunca os valores, para
// que uma senha jamais apareça em logs.
const VARIAVEIS_OBRIGATORIAS = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];

const faltando = VARIAVEIS_OBRIGATORIAS.filter((nome) => !process.env[nome]);
if (faltando.length > 0) {
  throw new Error(`Variáveis de ambiente ausentes: ${faltando.join(', ')}`);
}

// -----------------------------------------------------------------------------
// 2. Configuração de SSL/TLS (criptografia da conexão com o banco)
// -----------------------------------------------------------------------------
// - Local (Docker Compose): a API e o banco conversam por uma rede interna do
//   Docker, que não sai da sua máquina, então não usamos SSL (DB_SSL ausente).
// - AWS (RDS): o tráfego passa pela rede da nuvem e deve ser CRIPTOGRAFADO. No
//   RDS com PostgreSQL 15 ou mais novo, o SSL já vem OBRIGATÓRIO por padrão
//   (parâmetro rds.force_ssl=1), então sem SSL a conexão é recusada.
//
// rejectUnauthorized: true -> o Node VERIFICA se o certificado do servidor é
// legítimo. Isso é o que impede um ataque "man-in-the-middle" (alguém no meio
// do caminho se passando pelo banco). Muitos tutoriais usam "false" para o
// erro sumir, mas isso deixa a conexão criptografada sem saber COM QUEM,
// o que anula boa parte da proteção.
//
// DB_SSL_CA -> caminho para o certificado da Autoridade Certificadora (CA) da
// AWS. Os certificados do RDS não são assinados por CAs públicas que o Node já
// conhece, então precisamos informar qual CA confiar. Vamos tratar disso na
// etapa do Terraform/EC2.
function configurarSsl() {
  if (process.env.DB_SSL !== 'true') {
    return false; // SSL desligado (ambiente local)
  }

  return {
    rejectUnauthorized: true,
    // Se DB_SSL_CA foi informado, lê o arquivo do certificado. Caso contrário,
    // deixa "undefined" e o Node usa apenas as CAs que ele já conhece.
    ca: process.env.DB_SSL_CA
      ? fs.readFileSync(process.env.DB_SSL_CA, 'utf8')
      : undefined,
  };
}

// -----------------------------------------------------------------------------
// 3. Tipo DATE: devolver como texto, e não como objeto Date do JavaScript
// -----------------------------------------------------------------------------
// Por padrão, o driver "pg" converte colunas DATE ("2026-10-01") em um objeto
// Date do JavaScript à MEIA-NOITE DO FUSO LOCAL. Ao virar JSON, esse objeto é
// convertido para UTC e a data pode "mudar de dia":
//   "2026-10-01" -> Date às 00:00 em UTC-3 -> "2026-10-01T03:00:00.000Z"
// e, dependendo do fuso do servidor, até "2026-09-30T...".
//
// Uma reserva tem só DIA, sem hora, então pedimos ao driver para devolver o
// texto original "YYYY-MM-DD", sem conversão. 1082 é o identificador interno
// (OID) do tipo DATE no PostgreSQL.
types.setTypeParser(1082, (valor) => valor);

// -----------------------------------------------------------------------------
// 4. Pool de conexões
// -----------------------------------------------------------------------------
// Abrir uma conexão com o banco é caro (rede, autenticação, handshake SSL).
// O POOL mantém um conjunto de conexões abertas e as REUTILIZA: cada
// requisição "pega emprestada" uma conexão livre e a devolve ao terminar.
const pool = new Pool({
  host: process.env.DB_HOST,
  // Variáveis de ambiente são sempre texto, então convertemos a porta para
  // número. Se DB_PORT não for informada, usa a porta padrão do Postgres.
  port: Number(process.env.DB_PORT ?? 5432),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: configurarSsl(),

  max: 10, // No máximo 10 conexões simultâneas com o banco.
  idleTimeoutMillis: 30_000, // Fecha conexões ociosas há mais de 30 s.
  connectionTimeoutMillis: 5_000, // Desiste de conectar após 5 s (em vez de
  // esperar para sempre), para que o erro apareça rápido.
});

// Se uma conexão OCIOSA do pool cair (ex.: o banco reiniciou), o pool emite um
// evento "error". Sem este listener, o Node trata o evento como erro não
// tratado e DERRUBA o processo inteiro. Aqui só registramos no log: o pool
// descarta a conexão quebrada e abre outra quando precisar.
pool.on('error', (erro) => {
  console.error('Erro em conexão ociosa do pool:', erro.message);
});

// -----------------------------------------------------------------------------
// 5. Criação da tabela (executada na inicialização da API)
// -----------------------------------------------------------------------------
// Esta criação fica na API, e não num script SQL do container do Postgres,
// porque esses scripts só rodam no Docker local. No RDS da AWS eles não
// existem, e assim o mesmo código funciona nos dois ambientes.
//
// - IF NOT EXISTS: se a tabela já existir, não faz nada. Por isso é seguro
//   executar a cada inicialização, e os dados já gravados são preservados.
// - GENERATED ALWAYS AS IDENTITY: id autoincrementado no padrão SQL (a forma
//   moderna do antigo SERIAL). O "ALWAYS" impede que alguém informe o id
//   manualmente, porque quem gera os ids é sempre o banco.
// - CHECK: o próprio banco garante que o status seja um dos 3 valores
//   permitidos. É uma segunda camada de proteção, além da validação na API.
const SQL_CRIAR_TABELA = `
  CREATE TABLE IF NOT EXISTS reservas (
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente VARCHAR(100) NOT NULL,
    data    DATE NOT NULL,
    status  VARCHAR(20) NOT NULL
            CHECK (status IN ('pendente', 'confirmada', 'cancelada'))
  )
`;

async function inicializarBanco() {
  await pool.query(SQL_CRIAR_TABELA);
}

// -----------------------------------------------------------------------------
// 6. Exportação
// -----------------------------------------------------------------------------
// - pool: usado pelas rotas para executar as queries e pelo server.js para
//   fechar as conexões no encerramento.
// - inicializarBanco: chamada pelo server.js antes de o servidor aceitar
//   requisições.
module.exports = { pool, inicializarBanco };
