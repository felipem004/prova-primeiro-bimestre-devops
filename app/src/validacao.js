// =============================================================================
// validacao.js: regras de validação dos dados de entrada
// -----------------------------------------------------------------------------
// Regra de ouro da segurança: NUNCA confie em dados vindos do cliente.
// Tudo o que chega numa requisição (corpo JSON, parâmetros da URL) pode ter
// qualquer formato, inclusive um formato montado de propósito para quebrar a
// API. Por isso validamos TIPO, FORMATO e TAMANHO antes de chegar ao banco.
//
// Este módulo só contém funções "puras": recebem dados e devolvem um
// resultado, sem acessar banco, rede ou a requisição do Express. Isso deixa
// as regras fáceis de ler, de reutilizar e de testar isoladamente.
// =============================================================================

// Valores aceitos para o campo "status". São os mesmos do CHECK da tabela
// (db.js). O banco é a última barreira, e esta lista existe para devolver uma
// mensagem clara (400) em vez de um erro genérico do banco (500).
const STATUS_VALIDOS = ['pendente', 'confirmada', 'cancelada'];

// Tamanho máximo do nome do cliente. Precisa bater com o VARCHAR(100) da
// tabela, senão o banco rejeitaria textos maiores com um erro 500.
const TAMANHO_MAXIMO_CLIENTE = 100;

// Maior valor que cabe numa coluna INTEGER do PostgreSQL (2^31 - 1).
// Um id maior que isso faria o banco lançar um erro "out of range".
const ID_MAXIMO = 2_147_483_647;

// -----------------------------------------------------------------------------
// Validação de datas no formato "AAAA-MM-DD"
// -----------------------------------------------------------------------------
// Usamos duas etapas:
//   1. Expressão regular (regex): confere o FORMATO (4 dígitos, hífen, 2
//      dígitos, hífen, 2 dígitos). ^ e $ exigem que o texto INTEIRO siga o
//      padrão, e não só um pedaço dele.
//   2. "Ida e volta": montamos uma data com os números e conferimos se ela
//      continua igual. Isso pega datas que têm o formato certo, mas não
//      existem, como 2026-02-30. O JavaScript "corrige" essa data para
//      2026-03-02, e a diferença denuncia o problema.
// Usamos Date.UTC (e não o horário local) para que o fuso horário do servidor
// não interfira no resultado.
const REGEX_DATA = /^\d{4}-\d{2}-\d{2}$/;

function ehDataValida(texto) {
  if (typeof texto !== 'string' || !REGEX_DATA.test(texto)) {
    return false;
  }

  // "2026-10-01" -> [2026, 10, 1]
  const [ano, mes, dia] = texto.split('-').map(Number);

  // Nos objetos Date, os meses vão de 0 (janeiro) a 11 (dezembro), por isso o "mes - 1".
  const data = new Date(Date.UTC(ano, mes - 1, dia));

  return (
    data.getUTCFullYear() === ano &&
    data.getUTCMonth() === mes - 1 &&
    data.getUTCDate() === dia
  );
}

// -----------------------------------------------------------------------------
// Validação do corpo de uma reserva (usada no POST e no PUT)
// -----------------------------------------------------------------------------
// Retorna um objeto com:
//   - erros: lista de mensagens (vazia se estiver tudo certo)
//   - dados: só os campos permitidos, já limpos, prontos para o banco
//
// Juntamos TODOS os erros de uma vez, em vez de parar no primeiro, para que
// quem usa a API corrija tudo numa tentativa só.
function validarReserva(corpo) {
  const erros = [];

  // O corpo precisa ser um objeto JSON: não pode ser vazio, null nem uma lista.
  // No Express 5, se a requisição vier sem corpo JSON, req.body é "undefined".
  if (typeof corpo !== 'object' || corpo === null || Array.isArray(corpo)) {
    return {
      erros: ['O corpo da requisição deve ser um objeto JSON.'],
      dados: null,
    };
  }

  const { cliente, data, status } = corpo;

  // --- cliente: texto obrigatório, de 1 a 100 caracteres ---
  // trim() remove espaços do início e do fim, para que "   " não conte como
  // um nome válido.
  if (typeof cliente !== 'string' || cliente.trim() === '') {
    erros.push('O campo "cliente" é obrigatório e deve ser um texto.');
  } else if (cliente.trim().length > TAMANHO_MAXIMO_CLIENTE) {
    erros.push(
      `O campo "cliente" deve ter no máximo ${TAMANHO_MAXIMO_CLIENTE} caracteres.`
    );
  }

  // --- data: texto obrigatório no formato AAAA-MM-DD, e a data deve existir ---
  if (!ehDataValida(data)) {
    erros.push(
      'O campo "data" é obrigatório e deve ser uma data válida no formato AAAA-MM-DD.'
    );
  }

  // --- status: obrigatório e deve ser um dos valores permitidos ---
  if (!STATUS_VALIDOS.includes(status)) {
    erros.push(
      `O campo "status" é obrigatório e deve ser um destes valores: ${STATUS_VALIDOS.join(', ')}.`
    );
  }

  if (erros.length > 0) {
    return { erros, dados: null };
  }

  // Devolvemos um objeto NOVO, só com os 3 campos permitidos. Qualquer campo
  // extra enviado pelo cliente (ex.: "id") é descartado. Isso evita um ataque
  // chamado "mass assignment", em que alguém envia campos que não deveria
  // controlar para tentar alterá-los.
  return {
    erros: [],
    dados: { cliente: cliente.trim(), data, status },
  };
}

// -----------------------------------------------------------------------------
// Validação do :id da URL (usada em GET, PUT e DELETE /reservas/:id)
// -----------------------------------------------------------------------------
// Parâmetros de URL chegam SEMPRE como texto ("42", "abc", "-1", "1.5"...).
// Aceitamos só inteiros positivos que caibam numa coluna INTEGER.
// Retorna o número se for válido, ou null se não for.
//
// Sem esta validação, algo como /reservas/abc chegaria ao banco e geraria um
// erro 500. O correto é devolver 400 (requisição inválida).
const REGEX_ID = /^\d+$/; // Só dígitos: sem sinal, ponto ou letras.

function validarId(texto) {
  if (!REGEX_ID.test(texto)) {
    return null;
  }

  const id = Number(texto);

  if (id < 1 || id > ID_MAXIMO) {
    return null;
  }

  return id;
}

module.exports = { STATUS_VALIDOS, validarReserva, validarId };
