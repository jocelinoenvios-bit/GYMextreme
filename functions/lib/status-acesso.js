'use strict';

/**
 * Porta fiel de lib/utils/status_acesso.dart (Flutter) — mesma regra de
 * negocio (7 dias de tolerancia, mensagens de notificacao) tem que ficar
 * identica nos dois lados. Se um mudar, o outro precisa mudar junto.
 *
 * Sem dependencia de firebase-admin de proposito: da pra testar essa
 * logica isolada (ver test/status-acesso.test.js), sem precisar de
 * credencial nenhuma.
 */

const TOLERANCIA_MENSALIDADE_DIAS = 7;

function semHorario(data) {
  return new Date(data.getFullYear(), data.getMonth(), data.getDate());
}

const UM_DIA_MS = 24 * 60 * 60 * 1000;

/**
 * @param {Date|null} proximoVencimento
 * @param {Date} [hoje]
 * @param {number} [toleranciaDias]
 * @returns {{status: string, podeAcessar: boolean, diasParaVencimento?: number, diasAtraso?: number, diasToleranciaRestantes?: number}}
 */
function calcularStatusAcesso(proximoVencimento, hoje, toleranciaDias) {
  toleranciaDias = toleranciaDias == null ? TOLERANCIA_MENSALIDADE_DIAS : toleranciaDias;
  hoje = hoje || new Date();

  if (!proximoVencimento) {
    return { status: 'semRegistro', podeAcessar: true };
  }

  const referencia = semHorario(hoje);
  const vencimento = semHorario(proximoVencimento);

  if (referencia.getTime() <= vencimento.getTime()) {
    const diasParaVencimento = Math.round((vencimento.getTime() - referencia.getTime()) / UM_DIA_MS);
    return { status: 'emDia', podeAcessar: true, diasParaVencimento };
  }

  const diasAtraso = Math.round((referencia.getTime() - vencimento.getTime()) / UM_DIA_MS);
  const ultimoDiaTolerancia = new Date(vencimento.getTime() + toleranciaDias * UM_DIA_MS);

  if (referencia.getTime() <= ultimoDiaTolerancia.getTime()) {
    const diasToleranciaRestantes =
      Math.round((ultimoDiaTolerancia.getTime() - referencia.getTime()) / UM_DIA_MS) + 1;
    return { status: 'tolerancia', podeAcessar: true, diasAtraso, diasToleranciaRestantes };
  }

  return { status: 'bloqueado', podeAcessar: false, diasAtraso };
}

/**
 * Texto da notificacao automatica do dia, ou `null` se nenhuma mensagem
 * deve ser enviada hoje pra esse status.
 * @param {ReturnType<typeof calcularStatusAcesso>} status
 * @returns {string|null}
 */
function mensagemNotificacaoMensalidade(status) {
  switch (status.status) {
    case 'semRegistro':
      return null;

    case 'emDia':
      if (status.diasParaVencimento === 7) return 'Atenção! Sua mensalidade vence em 7 dias.';
      if (status.diasParaVencimento === 3) return 'Sua mensalidade está próxima do vencimento.';
      if (status.diasParaVencimento === 0) return 'Sua mensalidade vence hoje.';
      return null;

    case 'tolerancia':
      if (status.diasAtraso === 1) {
        return (
          'Sua mensalidade está vencida. Você possui ' +
          TOLERANCIA_MENSALIDADE_DIAS +
          ' dias de tolerância para continuar utilizando normalmente a academia.'
        );
      }
      if (status.diasToleranciaRestantes === 1) {
        return 'Hoje é o último dia de tolerância. Regularize sua mensalidade para evitar o bloqueio.';
      }
      if (status.diasToleranciaRestantes != null) {
        return 'Restam ' + status.diasToleranciaRestantes + ' dias de tolerância.';
      }
      return null;

    case 'bloqueado':
      // So no primeiro dia de bloqueio — nao repete todo dia.
      if (status.diasAtraso === TOLERANCIA_MENSALIDADE_DIAS + 1) {
        return (
          'Sua mensalidade permanece em atraso. Seu acesso ao aplicativo e ' +
          'à academia foi bloqueado até a regularização do pagamento.'
        );
      }
      return null;

    default:
      return null;
  }
}

module.exports = {
  TOLERANCIA_MENSALIDADE_DIAS,
  calcularStatusAcesso,
  mensagemNotificacaoMensalidade,
};
