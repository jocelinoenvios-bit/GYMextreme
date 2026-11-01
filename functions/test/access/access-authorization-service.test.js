'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { avaliarAcesso } = require('../../lib/access/access-authorization-service');
const { MOTIVO_NEGACAO, RESULTADO } = require('../../lib/access/motivos');

const hoje = new Date(2026, 7, 15); // 15/ago/2026

function timestamp(date) {
  return { toDate: () => date };
}

function alunoBase(overrides) {
  return {
    ativo: true,
    bloqueado: false,
    proximoVencimento: timestamp(new Date(2026, 8, 1)), // 01/set — em dia
    unidadeId: null,
    ...overrides,
  };
}

function matriculaAtivaBase(overrides) {
  return {
    status: 'ativa',
    dataVencimento: timestamp(new Date(2026, 8, 1)),
    ...overrides,
  };
}

const dispositivoBase = { unidadeId: 'unidade-1' };

// Teste 1 — aluno ativo + pagamento em dia: ALLOW
test('Teste 1: aluno ativo, plano vigente e mensalidade em dia libera acesso', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase(),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.deepEqual(decisao, { resultado: RESULTADO.ALLOW, motivo: null });
});

// Teste 2 — aluno inadimplente: DENY
test('Teste 2: mensalidade em atraso (fora da tolerância) nega com PAYMENT_OVERDUE', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ proximoVencimento: timestamp(new Date(2026, 6, 1)) }), // vencida há > 7 dias
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.PAYMENT_OVERDUE);
});

// Teste 3 — aluno inexistente: DENY
test('Teste 3: aluno nulo (não encontrado) nega com STUDENT_NOT_FOUND', () => {
  const decisao = avaliarAcesso({
    aluno: null,
    matriculaAtiva: null,
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.STUDENT_NOT_FOUND);
});

// Teste 4 — aluno bloqueado: DENY
test('Teste 4: aluno com bloqueado=true nega com STUDENT_BLOCKED, mesmo em dia', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ bloqueado: true }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.STUDENT_BLOCKED);
});

test('aluno com ativo=false nega com STUDENT_INACTIVE', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ ativo: false }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.STUDENT_INACTIVE);
});

// Teste 5 — plano expirado: DENY
test('Teste 5: sem nenhuma matrícula ativa nega com PLAN_EXPIRED', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase(),
    matriculaAtiva: null,
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.PLAN_EXPIRED);
});

test('Teste 5b: matrícula com status "ativa" mas dataVencimento no passado também nega com PLAN_EXPIRED', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase(),
    matriculaAtiva: matriculaAtivaBase({ dataVencimento: timestamp(new Date(2026, 6, 1)) }),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.PLAN_EXPIRED);
});

// Teste 6 — fora do horário: comportamento atual é sempre permitir (não
// existe configuração de horário de acesso no app ainda — ver docstring
// do serviço). Este teste documenta esse comportamento explicitamente,
// pra não ser confundido com "esquecido".
test('Teste 6: horário de acesso ainda não é validado (funcionalidade não existe no app) — nunca bloqueia por isso', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase(),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: new Date(2026, 7, 15, 3, 0), // 3h da manhã — hipotético fora de horário
  });
  assert.equal(decisao.resultado, RESULTADO.ALLOW);
});

// Teste 7 — unidade não permitida: DENY
test('Teste 7: aluno de outra unidade nega com UNIT_NOT_ALLOWED', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ unidadeId: 'unidade-2' }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase, // unidade-1
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.DENY);
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.UNIT_NOT_ALLOWED);
});

test('aluno sem unidadeId definido (cadastro legado) nunca é barrado por unidade', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ unidadeId: null }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.ALLOW);
});

test('mesma unidade do aluno e do dispositivo libera normalmente', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ unidadeId: 'unidade-1' }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.ALLOW);
});

test('sem proximoVencimento configurado (nunca cobrado ainda) não bloqueia por mensalidade', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({ proximoVencimento: null }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.resultado, RESULTADO.ALLOW);
});

test('ordem das checagens: aluno bloqueado prevalece mesmo com mensalidade também atrasada', () => {
  const decisao = avaliarAcesso({
    aluno: alunoBase({
      bloqueado: true,
      proximoVencimento: timestamp(new Date(2026, 6, 1)),
    }),
    matriculaAtiva: matriculaAtivaBase(),
    dispositivo: dispositivoBase,
    agora: hoje,
  });
  assert.equal(decisao.motivo, MOTIVO_NEGACAO.STUDENT_BLOCKED);
});
