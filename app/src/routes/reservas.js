// =============================================================================
// routes/reservas.js: rotas do CRUD de reservas
// -----------------------------------------------------------------------------
// Este arquivo junta as peças:
//   - validacao.js -> confere se os dados recebidos são válidos
//   - db.js        -> executa as queries no PostgreSQL
//
// Usamos um "Router" do Express: um mini-aplicativo só com rotas. As rotas
// aqui são escritas RELATIVAS ("/" e "/:id"), e o app.js as "monta" no
// prefixo "/reservas". Assim, "/:id" aqui vira "/reservas/:id" na API.
//
// Tratamento de erros: no Express 5, se uma função async lançar um erro (ex.:
// o banco caiu), o próprio Express o captura e o repassa ao tratador de erros
// central (que ficará no app.js). Por isso não há try/catch em cada rota.
//
// SEGURANÇA - SQL INJECTION:
// Todas as queries usam PARÂMETROS ($1, $2...). Os valores seguem para o banco
// SEPARADOS do texto SQL, e o banco os trata sempre como DADOS, nunca como
// comandos. Por isso um cliente chamado "'; DROP TABLE reservas; --" é salvo
// como um nome estranho, mas inofensivo.
// NUNCA monte SQL concatenando texto do usuário, como `WHERE id = ${id}`.
//
// Todas as queries listam as colunas explicitamente em vez de usar "SELECT *".
// Se um dia a tabela ganhar uma coluna interna (ex.: dados de auditoria), ela
// não vaza para a resposta da API sem alguém decidir isso.
// =============================================================================

const express = require('express');
const { pool } = require('../db');
const { validarReserva, validarId } = require('../validacao');

const router = express.Router();

// -----------------------------------------------------------------------------
// Respostas de erro reutilizadas por várias rotas
// -----------------------------------------------------------------------------
// Todas as respostas de erro seguem o mesmo formato { erros: [...] }, para que
// quem consome a API trate os erros sempre do mesmo jeito.
function responderIdInvalido(res) {
  return res.status(400).json({
    erros: ['O id deve ser um número inteiro positivo.'],
  });
}

function responderNaoEncontrada(res) {
  return res.status(404).json({ erros: ['Reserva não encontrada.'] });
}

// -----------------------------------------------------------------------------
// POST /reservas -> CREATE: cria uma nova reserva
// -----------------------------------------------------------------------------
router.post('/', async (req, res) => {
  const { erros, dados } = validarReserva(req.body);
  if (erros.length > 0) {
    return res.status(400).json({ erros });
  }

  // RETURNING devolve a linha recém-inserida (incluindo o id gerado pelo
  // banco) na mesma operação, sem precisar de um SELECT extra.
  const resultado = await pool.query(
    `INSERT INTO reservas (cliente, data, status)
     VALUES ($1, $2, $3)
     RETURNING id, cliente, data, status`,
    [dados.cliente, dados.data, dados.status]
  );

  const reserva = resultado.rows[0];

  // 201 Created: o código HTTP correto para "recurso criado com sucesso".
  // O cabeçalho Location informa o endereço do novo recurso, como manda a
  // especificação HTTP para o 201.
  return res
    .status(201)
    .location(`/reservas/${reserva.id}`)
    .json(reserva);
});

// -----------------------------------------------------------------------------
// GET /reservas -> READ: lista todas as reservas
// -----------------------------------------------------------------------------
router.get('/', async (req, res) => {
  // ORDER BY garante uma ordem previsível: sem ele, o PostgreSQL pode
  // devolver as linhas em qualquer ordem.
  const resultado = await pool.query(
    'SELECT id, cliente, data, status FROM reservas ORDER BY id'
  );

  // Se não houver reservas, rows é uma lista vazia [] e a resposta continua
  // sendo 200. Uma lista vazia é uma resposta válida, não um erro.
  return res.json(resultado.rows);
});

// -----------------------------------------------------------------------------
// GET /reservas/:id -> READ: busca uma reserva pelo id
// -----------------------------------------------------------------------------
router.get('/:id', async (req, res) => {
  const id = validarId(req.params.id);
  if (id === null) {
    return responderIdInvalido(res);
  }

  const resultado = await pool.query(
    'SELECT id, cliente, data, status FROM reservas WHERE id = $1',
    [id]
  );

  // rowCount = quantidade de linhas afetadas/retornadas pela query.
  if (resultado.rowCount === 0) {
    return responderNaoEncontrada(res);
  }

  return res.json(resultado.rows[0]);
});

// -----------------------------------------------------------------------------
// PUT /reservas/:id -> UPDATE: substitui os dados de uma reserva existente
// -----------------------------------------------------------------------------
// PUT substitui o recurso INTEIRO, por isso exige os 3 campos (a mesma
// validação do POST). Uma atualização parcial seria função do PATCH.
router.put('/:id', async (req, res) => {
  const id = validarId(req.params.id);
  if (id === null) {
    return responderIdInvalido(res);
  }

  const { erros, dados } = validarReserva(req.body);
  if (erros.length > 0) {
    return res.status(400).json({ erros });
  }

  // Fazemos o UPDATE direto, sem um SELECT antes para conferir se a reserva
  // existe. Se o id não existir, nenhuma linha é afetada (rowCount = 0). Isso
  // economiza uma ida ao banco e evita uma "condição de corrida" (a reserva
  // ser apagada entre o SELECT e o UPDATE).
  const resultado = await pool.query(
    `UPDATE reservas
     SET cliente = $1, data = $2, status = $3
     WHERE id = $4
     RETURNING id, cliente, data, status`,
    [dados.cliente, dados.data, dados.status, id]
  );

  if (resultado.rowCount === 0) {
    return responderNaoEncontrada(res);
  }

  return res.json(resultado.rows[0]);
});

// -----------------------------------------------------------------------------
// DELETE /reservas/:id -> DELETE: remove uma reserva
// -----------------------------------------------------------------------------
router.delete('/:id', async (req, res) => {
  const id = validarId(req.params.id);
  if (id === null) {
    return responderIdInvalido(res);
  }

  const resultado = await pool.query('DELETE FROM reservas WHERE id = $1', [
    id,
  ]);

  if (resultado.rowCount === 0) {
    return responderNaoEncontrada(res);
  }

  // 204 No Content: deu certo e não há nada para devolver no corpo.
  // .end() encerra a resposta sem corpo.
  return res.status(204).end();
});

module.exports = router;
