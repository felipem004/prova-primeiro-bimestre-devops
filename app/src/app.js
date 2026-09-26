// =============================================================================
// app.js: configuração da aplicação Express
// -----------------------------------------------------------------------------
// Este arquivo DESCREVE a aplicação: quais middlewares ela usa, quais rotas ela
// tem e como trata os erros. Ele NÃO liga o servidor; isso fica no server.js.
//
// O que é um MIDDLEWARE? É uma função que a requisição atravessa no caminho até
// a resposta. O Express executa os middlewares NA ORDEM em que são registrados
// com app.use(), como uma linha de montagem:
//
//   requisição -> [lê o JSON] -> [rotas] -> [404] -> [tratador de erros]
//
// Por isso a ORDEM dos app.use() neste arquivo importa.
// =============================================================================

const express = require('express');
const { pool } = require('./db');
const reservasRouter = require('./routes/reservas');

const app = express();

// -----------------------------------------------------------------------------
// 1. Esconder a identificação do framework
// -----------------------------------------------------------------------------
// Por padrão, o Express envia o cabeçalho "X-Powered-By: Express" em todas as
// respostas. Isso revela a tecnologia usada e ajuda um atacante a procurar
// falhas conhecidas daquela tecnologia. Desligar não torna a API invulnerável,
// mas não há motivo para entregar essa informação.
app.disable('x-powered-by');

// -----------------------------------------------------------------------------
// 2. Leitura do corpo JSON das requisições
// -----------------------------------------------------------------------------
// express.json() lê o corpo das requisições com "Content-Type: application/json"
// e o converte em objeto JavaScript, disponível em req.body.
//
// limit: '10kb' -> rejeita corpos maiores que 10 KB com o erro 413. Uma reserva
// tem poucos bytes, e sem limite alguém poderia enviar corpos enormes para
// consumir memória e CPU do servidor (um tipo de ataque de negação de serviço).
app.use(express.json({ limit: '10kb' }));

// -----------------------------------------------------------------------------
// 3. Health check: GET /health
// -----------------------------------------------------------------------------
// O healthcheck do Docker Compose chama esta rota periodicamente para saber se
// a API está saudável.
//
// Ela também testa o BANCO ("SELECT 1" é a consulta mais leve possível). Se a
// API estiver no ar mas sem conseguir falar com o banco, ela não consegue
// atender ninguém, então não deve ser considerada saudável.
//
// Aqui o try/catch é necessário (diferente das rotas de reservas), porque
// queremos responder 503 (Service Unavailable, "serviço indisponível no
// momento") em vez de deixar o erro virar um 500 genérico.
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.json({ status: 'ok' });
  } catch (erro) {
    // O detalhe do erro vai só para o log do servidor. Quem chamou a rota recebe
    // apenas o status, sem informações internas (endereço do banco, usuário...).
    console.error('Health check falhou:', erro.message);
    return res.status(503).json({ status: 'indisponivel' });
  }
});

// -----------------------------------------------------------------------------
// 4. Rotas de reservas
// -----------------------------------------------------------------------------
// "Monta" o router no prefixo /reservas: a rota "/:id" definida em
// routes/reservas.js passa a responder em "/reservas/:id".
app.use('/reservas', reservasRouter);

// -----------------------------------------------------------------------------
// 5. Rota não encontrada (404)
// -----------------------------------------------------------------------------
// Se a requisição chegou até aqui, nenhuma rota acima a atendeu. Por isso este
// middleware precisa vir DEPOIS de todas as rotas. Sem ele, o Express
// responderia com uma página HTML padrão, fora do formato JSON da API.
app.use((req, res) => {
  res.status(404).json({ erros: ['Rota não encontrada.'] });
});

// -----------------------------------------------------------------------------
// 6. Tratador de erros central
// -----------------------------------------------------------------------------
// O Express reconhece um tratador de erros por ter QUATRO parâmetros
// (erro, req, res, next). Todo erro lançado nas rotas acaba aqui, inclusive os
// erros de funções async, que o Express 5 repassa sozinho.
//
// Princípio de segurança: o cliente recebe uma mensagem GENÉRICA, e o detalhe
// completo (mensagem e stack trace) fica só no log do servidor. Um stack trace
// na resposta revelaria caminhos de arquivos, bibliotecas, versões e até
// trechos de SQL, um mapa útil para um atacante.
app.use((erro, req, res, next) => {
  // Se a resposta já começou a ser enviada, não dá para trocar o status. Nesse
  // caso, delegamos ao tratador padrão do Express, que encerra a conexão.
  if (res.headersSent) {
    return next(erro);
  }

  // Erros causados pelo CLIENTE ao enviar o corpo, gerados pelo express.json().
  // A propriedade "type" identifica o tipo de erro.
  if (erro.type === 'entity.parse.failed') {
    // JSON malformado, ex.: {"cliente": "Ana",} (vírgula sobrando).
    return res.status(400).json({ erros: ['JSON inválido no corpo da requisição.'] });
  }
  if (erro.type === 'entity.too.large') {
    // Corpo maior que o limite de 10 KB definido acima.
    return res.status(413).json({ erros: ['Corpo da requisição muito grande.'] });
  }

  // Outros erros 4xx sinalizados por bibliotecas (ex.: codificação não
  // suportada). Respondemos com o status original, mas com mensagem genérica.
  const status = erro.status ?? erro.statusCode;
  if (status >= 400 && status < 500) {
    return res.status(status).json({ erros: ['Requisição inválida.'] });
  }

  // Qualquer outro erro é um problema NOSSO (banco fora do ar, bug...):
  // registramos tudo no log e devolvemos um 500 genérico.
  console.error('Erro inesperado:', erro);
  return res.status(500).json({ erros: ['Erro interno do servidor.'] });
});

module.exports = app;
