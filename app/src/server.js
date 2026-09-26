// =============================================================================
// server.js: ponto de entrada da API (é o arquivo que o Dockerfile executa)
// -----------------------------------------------------------------------------
// Responsabilidades:
//   1. Preparar o banco (criar a tabela), tentando de novo se ele ainda não
//      estiver pronto.
//   2. Ligar o servidor HTTP na porta configurada.
//   3. Encerrar de forma LIMPA ao receber um sinal de parada (docker stop,
//      Ctrl+C), sem cortar requisições no meio nem deixar conexões abertas.
// =============================================================================

// setTimeout em versão "Promise": permite escrever "await esperar(3000)" para
// pausar a execução por 3 segundos. O nome foi trocado para "esperar" para
// não confundir com o setTimeout global, que também é usado neste arquivo.
const { setTimeout: esperar } = require('node:timers/promises');

// Ao importar o app, o db.js também é carregado e valida as variáveis de
// ambiente. Se faltar alguma, o processo já para aqui, com mensagem clara.
const app = require('./app');
const { pool, inicializarBanco } = require('./db');

// Porta HTTP: vem da variável de ambiente PORT ou, se ela não existir, 3000
// (a mesma do EXPOSE no Dockerfile).
const PORTA = Number(process.env.PORT ?? 3000);

// Configuração das novas tentativas de conexão com o banco.
const MAX_TENTATIVAS_BANCO = 10;
const INTERVALO_TENTATIVAS_MS = 3_000;

// Tempo máximo para o encerramento limpo. O "docker stop" espera 10 s antes de
// matar o processo à força (SIGKILL), então usamos um valor um pouco menor
// para encerrar por conta própria antes disso.
const TEMPO_MAXIMO_ENCERRAMENTO_MS = 8_000;

// -----------------------------------------------------------------------------
// 1. Inicialização do banco, com novas tentativas
// -----------------------------------------------------------------------------
// Por que tentar mais de uma vez? Quando os containers sobem juntos, ou quando
// a EC2 liga, o banco pode levar alguns segundos para aceitar conexões. Em vez
// de desistir na primeira falha, a API tenta de novo algumas vezes. Se todas
// falharem, o erro é lançado e o processo termina com código de falha.
//
// No Docker Compose, o "depends_on" com "condition: service_healthy" já vai
// segurar a API até o banco estar pronto. As novas tentativas são uma segunda
// garantia, útil principalmente na AWS, onde não existe depends_on.
async function inicializarBancoComTentativas() {
  for (let tentativa = 1; tentativa <= MAX_TENTATIVAS_BANCO; tentativa++) {
    try {
      await inicializarBanco();
      console.log('Banco de dados pronto.');
      return;
    } catch (erro) {
      if (tentativa === MAX_TENTATIVAS_BANCO) {
        throw erro; // Esgotou as tentativas: desiste.
      }
      console.warn(
        `Banco indisponível (tentativa ${tentativa}/${MAX_TENTATIVAS_BANCO}): ` +
          `${erro.message}. Nova tentativa em ${INTERVALO_TENTATIVAS_MS / 1000}s...`
      );
      await esperar(INTERVALO_TENTATIVAS_MS);
    }
  }
}

// -----------------------------------------------------------------------------
// 2. Encerramento limpo ("graceful shutdown")
// -----------------------------------------------------------------------------
// Ao receber SIGTERM (enviado pelo "docker stop") ou SIGINT (Ctrl+C no
// terminal), a API:
//   a) para de aceitar NOVAS conexões;
//   b) espera as requisições em andamento terminarem;
//   c) fecha as conexões com o banco (pool.end);
//   d) encerra o processo com código 0 (sucesso).
//
// Sem isso, uma requisição no meio de um UPDATE poderia ser cortada e o
// cliente ficaria sem resposta. Além disso, o container ficaria os 10 s
// inteiros esperando até o Docker matá-lo à força.
function configurarEncerramento(servidor) {
  let encerrando = false;

  async function encerrar(sinal) {
    // Evita rodar o encerramento duas vezes (ex.: Ctrl+C apertado duas vezes).
    if (encerrando) return;
    encerrando = true;

    console.log(`Sinal ${sinal} recebido. Encerrando a API...`);

    // Plano B: se algo travar (ex.: uma requisição que nunca termina), força a
    // saída depois do tempo máximo. O .unref() faz com que este timer, sozinho,
    // não mantenha o processo vivo: se tudo terminar antes, o Node pode sair
    // sem esperar por ele.
    setTimeout(() => {
      console.error('Encerramento demorou demais. Forçando saída.');
      process.exit(1);
    }, TEMPO_MAXIMO_ENCERRAMENTO_MS).unref();

    // servidor.close() para de aceitar conexões e chama a função passada quando
    // as requisições em andamento terminarem.
    servidor.close(async () => {
      await pool.end(); // Fecha todas as conexões do pool com o banco.
      console.log('API encerrada com sucesso.');
      process.exit(0);
    });
  }

  // process.on registra uma função para ser chamada quando o processo receber
  // o sinal. Sem esses registros, o Node, rodando como PID 1 no container,
  // IGNORARIA o SIGTERM.
  process.on('SIGTERM', () => encerrar('SIGTERM'));
  process.on('SIGINT', () => encerrar('SIGINT'));
}

// -----------------------------------------------------------------------------
// 3. Sequência de inicialização
// -----------------------------------------------------------------------------
// O servidor só começa a aceitar requisições DEPOIS de o banco estar pronto.
// Assim nenhuma requisição chega antes de a tabela existir.
async function iniciar() {
  await inicializarBancoComTentativas();

  // app.listen() liga o servidor HTTP. Sem informar o endereço, ele escuta em
  // TODAS as interfaces de rede. Isso é necessário dentro do container: se
  // escutasse só em "localhost", ficaria inacessível de fora do container.
  //
  // No Express 5, se a porta não puder ser usada (ex.: já ocupada por outro
  // programa), a função de callback recebe o erro.
  const servidor = app.listen(PORTA, (erro) => {
    if (erro) {
      console.error('Não foi possível iniciar o servidor:', erro.message);
      process.exit(1);
    }
    console.log(`API de Reservas ouvindo na porta ${PORTA}.`);
  });

  configurarEncerramento(servidor);
}

// Qualquer erro fatal na inicialização (ex.: banco inacessível após todas as
// tentativas) é registrado no log, e o processo termina com código 1. Um código
// diferente de 0 indica FALHA para o Docker, que pode então reiniciar o
// container, conforme a política de "restart" configurada no Compose.
iniciar().catch((erro) => {
  console.error('Falha ao iniciar a API:', erro.message);
  process.exit(1);
});
