'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  DIAS_MENSAGEM_RETORNO,
  DIAS_INATIVACAO,
  DIAS_MENSAGEM_REATIVACAO,
  idMensagemWhatsapp,
  avaliarCicloInadimplencia,
  montarMensagemWhatsapp,
} = require('../lib/inadimplencia');

const vencimento = new Date(2026, 7, 10); // 10/ago/2026 (mes 0-indexado)

function diasDepois(data, dias) {
  return new Date(data.getTime() + dias * 24 * 60 * 60 * 1000);
}

test('TESTE 1: mensalidade vence hoje → nenhuma acao', () => {
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: vencimento, dataInativacao: null },
    vencimento,
  );
  assert.equal(acao.tipo, 'nenhuma');
});

test('TESTE 2: 14 dias de atraso → nenhuma mensagem de 15 dias ainda', () => {
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: vencimento, dataInativacao: null },
    diasDepois(vencimento, DIAS_MENSAGEM_RETORNO - 1),
  );
  assert.equal(acao.tipo, 'nenhuma');
});

test('TESTE 3: 15 dias de atraso → mensagem de retorno', () => {
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: vencimento, dataInativacao: null },
    diasDepois(vencimento, DIAS_MENSAGEM_RETORNO),
  );
  assert.equal(acao.tipo, 'mensagemRetorno15');
  assert.deepEqual(acao.vencimentoReferencia, vencimento);
});

test('TESTE 4: 16 dias de atraso → decisão continua "mandar mensagem" (idempotência é responsabilidade de quem grava, não desta função)', () => {
  // avaliarCicloInadimplencia é pura e sempre olha só a data — quem evita
  // reenviar é o Firestore doc idempotente em processarCicloInadimplencia
  // (ver test/inadimplencia.emulator.js), chave por idMensagemWhatsapp.
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: vencimento, dataInativacao: null },
    diasDepois(vencimento, DIAS_MENSAGEM_RETORNO + 1),
  );
  assert.equal(acao.tipo, 'mensagemRetorno15');
  // A chave de idempotência é a MESMA no dia 15 e no dia 16 (mesmo
  // vencimento de referência) — é isso que impede o reenvio.
  const chave15 = idMensagemWhatsapp('mensagemRetorno15', vencimento);
  const chave16 = idMensagemWhatsapp('mensagemRetorno15', acao.vencimentoReferencia);
  assert.equal(chave15, chave16);
});

test('TESTE 5: 30 dias de atraso → inativar', () => {
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: vencimento, dataInativacao: null },
    diasDepois(vencimento, DIAS_INATIVACAO),
  );
  assert.equal(acao.tipo, 'inativar');
});

test('30 dias sempre vence sobre 15 (se o job atrasou alguns dias, nunca manda "retorno" quando já devia estar inativo)', () => {
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: vencimento, dataInativacao: null },
    diasDepois(vencimento, DIAS_INATIVACAO + 5),
  );
  assert.equal(acao.tipo, 'inativar');
});

test('TESTE 6: aluno inativo sem dataInativacao (dado legado) nunca gera divida nem mensagem — so nenhuma acao', () => {
  const acao = avaliarCicloInadimplencia(
    { ativo: false, proximoVencimento: vencimento, dataInativacao: null },
    diasDepois(vencimento, 200),
  );
  assert.equal(acao.tipo, 'nenhuma');
});

test('TESTE 6b: aluno inativo continua "nenhuma acao" antes dos 45 dias de afastamento', () => {
  const dataInativacao = diasDepois(vencimento, DIAS_INATIVACAO);
  const acao = avaliarCicloInadimplencia(
    { ativo: false, proximoVencimento: vencimento, dataInativacao },
    diasDepois(dataInativacao, DIAS_MENSAGEM_REATIVACAO - 1),
  );
  assert.equal(acao.tipo, 'nenhuma');
});

test('TESTE 7: 45 dias de inatividade → segunda mensagem', () => {
  const dataInativacao = diasDepois(vencimento, DIAS_INATIVACAO);
  const acao = avaliarCicloInadimplencia(
    { ativo: false, proximoVencimento: vencimento, dataInativacao },
    diasDepois(dataInativacao, DIAS_MENSAGEM_REATIVACAO),
  );
  assert.equal(acao.tipo, 'mensagemReativacao45');
  assert.deepEqual(acao.dataInativacao, dataInativacao);
});

test('TESTE 9: aluno reativado (ativo=true de novo) volta a seguir o vencimento novo, novo ciclo 15/30/45', () => {
  const novoVencimento = new Date(2027, 0, 20);
  const acao = avaliarCicloInadimplencia(
    { ativo: true, proximoVencimento: novoVencimento, dataInativacao: diasDepois(vencimento, 30) },
    diasDepois(novoVencimento, DIAS_MENSAGEM_RETORNO),
  );
  assert.equal(acao.tipo, 'mensagemRetorno15');
  assert.deepEqual(acao.vencimentoReferencia, novoVencimento);

  // A chave de mensagem do novo ciclo é diferente da do ciclo antigo —
  // nunca reaproveita o evento anterior.
  const chaveAntiga = idMensagemWhatsapp('mensagemRetorno15', vencimento);
  const chaveNova = idMensagemWhatsapp('mensagemRetorno15', novoVencimento);
  assert.notEqual(chaveAntiga, chaveNova);
});

test('idMensagemWhatsapp usa o fuso de Sao Paulo e e estavel pro mesmo dia', () => {
  const a = idMensagemWhatsapp('mensagemRetorno15', new Date(2026, 7, 25, 3));
  const b = idMensagemWhatsapp('mensagemRetorno15', new Date(2026, 7, 25, 23));
  assert.equal(a, b);
});

test('montarMensagemWhatsapp usa so o primeiro nome e nunca fica vazio', () => {
  const msg15 = montarMensagemWhatsapp('mensagemRetorno15', 'Maria Souza');
  assert.match(msg15, /Olá, Maria!/);
  assert.match(msg15, /GYMEXTREME/);

  const msg45 = montarMensagemWhatsapp('mensagemReativacao45', null);
  assert.match(msg45, /Olá, aluno!/);
});
