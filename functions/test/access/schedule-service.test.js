'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  diaEHoraLocal,
  resolverHorariosPermitidos,
  estaDentroDoHorarioPermitido,
} = require('../../lib/access/schedule-service');

// ATENÇÃO: os horários abaixo são FIXTURES DE TESTE, só pra validar a
// lógica — não são o horário real de nenhuma academia. Nenhum horário
// padrão é assumido pelo serviço em si (ver os testes de "sem
// configuração" mais abaixo).
const HORARIO_FIXTURE_TESTE = Object.freeze({
  segunda: [{ inicio: '06:00', fim: '10:00' }, { inicio: '16:00', fim: '22:00' }],
  terca: [{ inicio: '06:00', fim: '22:00' }],
  sabado: [{ inicio: '08:00', fim: '14:00' }],
  domingo: [], // fechado nesse dia (fixture de teste)
  // quarta/quinta/sexta ausentes de propósito: sem restrição nesses dias
});

test('diaEHoraLocal converte pro fuso de Sao Paulo, nao pro fuso local do processo', () => {
  // 2026-01-05T02:30:00Z = 2026-01-04 23:30 em America/Sao_Paulo (UTC-3)
  // — atravessa a meia-noite, dia da semana muda conforme o fuso usado.
  const data = new Date('2026-01-05T02:30:00Z');
  const { dia, horaMinuto } = diaEHoraLocal(data, 'America/Sao_Paulo');
  assert.equal(dia, 'domingo'); // 04/jan/2026 e domingo
  assert.equal(horaMinuto, '23:30');
});

test('resolverHorariosPermitidos: sem configuracao em nenhum nivel, retorna null (sem restricao)', () => {
  assert.equal(resolverHorariosPermitidos({ aluno: null, plano: null, unidade: null }), null);
  assert.equal(resolverHorariosPermitidos({ aluno: {}, plano: {}, unidade: {} }), null);
});

test('resolverHorariosPermitidos: aluno tem prioridade sobre plano e unidade', () => {
  const horarioAluno = { segunda: [] };
  const horarioPlano = { segunda: [{ inicio: '00:00', fim: '23:59' }] };
  const resolvido = resolverHorariosPermitidos({
    aluno: { horariosPermitidos: horarioAluno },
    plano: { horariosPermitidos: horarioPlano },
    unidade: null,
  });
  assert.deepEqual(resolvido, horarioAluno);
});

test('resolverHorariosPermitidos: plano tem prioridade sobre unidade quando aluno nao tem', () => {
  const horarioPlano = { segunda: [] };
  const horarioUnidade = { segunda: [{ inicio: '00:00', fim: '23:59' }] };
  const resolvido = resolverHorariosPermitidos({
    aluno: {},
    plano: { horariosPermitidos: horarioPlano },
    unidade: { horariosPermitidos: horarioUnidade },
  });
  assert.deepEqual(resolvido, horarioPlano);
});

test('resolverHorariosPermitidos: unidade e usada só quando aluno e plano nao tem', () => {
  const horarioUnidade = { segunda: [{ inicio: '00:00', fim: '23:59' }] };
  const resolvido = resolverHorariosPermitidos({
    aluno: {},
    plano: {},
    unidade: { horariosPermitidos: horarioUnidade },
  });
  assert.deepEqual(resolvido, horarioUnidade);
});

test('estaDentroDoHorarioPermitido: sem nenhuma configuracao (null), sempre permite', () => {
  assert.equal(
    estaDentroDoHorarioPermitido({ horariosPermitidos: null, agora: new Date('2026-01-05T02:30:00Z') }),
    true,
  );
});

test('estaDentroDoHorarioPermitido: dentro da faixa (fixture de teste) permite', () => {
  // Terca, 10:00 em Sao Paulo -> dentro de 06:00-22:00
  const agora = new Date('2026-01-06T13:00:00Z'); // 2026-01-06 = terça
  const permitido = estaDentroDoHorarioPermitido({ horariosPermitidos: HORARIO_FIXTURE_TESTE, agora });
  assert.equal(permitido, true);
});

test('estaDentroDoHorarioPermitido: fora da faixa (fixture de teste) bloqueia', () => {
  // Segunda, 12:00 em Sao Paulo -> fora das faixas 06:00-10:00 e 16:00-22:00
  const agora = new Date('2026-01-05T15:00:00Z'); // 2026-01-05 = segunda, 12:00 BRT
  const permitido = estaDentroDoHorarioPermitido({ horariosPermitidos: HORARIO_FIXTURE_TESTE, agora });
  assert.equal(permitido, false);
});

test('estaDentroDoHorarioPermitido: segunda faixa do mesmo dia tambem permite (multiplas faixas)', () => {
  // Segunda, 18:00 em Sao Paulo -> dentro da segunda faixa 16:00-22:00
  const agora = new Date('2026-01-05T21:00:00Z');
  const permitido = estaDentroDoHorarioPermitido({ horariosPermitidos: HORARIO_FIXTURE_TESTE, agora });
  assert.equal(permitido, true);
});

test('estaDentroDoHorarioPermitido: dia com array vazio explicito (fechado) sempre bloqueia', () => {
  // Domingo -> array vazio no fixture = fechado o dia inteiro
  const agora = new Date('2026-01-04T15:00:00Z'); // domingo, qualquer hora
  const permitido = estaDentroDoHorarioPermitido({ horariosPermitidos: HORARIO_FIXTURE_TESTE, agora });
  assert.equal(permitido, false);
});

test('estaDentroDoHorarioPermitido: dia ausente do objeto (nao configurado) nunca bloqueia', () => {
  // Quarta nao esta no fixture -> sem restricao nesse dia
  const agora = new Date('2026-01-07T05:00:00Z'); // quarta, 02:00 BRT (bem cedo)
  const permitido = estaDentroDoHorarioPermitido({ horariosPermitidos: HORARIO_FIXTURE_TESTE, agora });
  assert.equal(permitido, true);
});

test('estaDentroDoHorarioPermitido: exatamente no limite inicial/final da faixa permite (inclusivo)', () => {
  const horario = { segunda: [{ inicio: '08:00', fim: '18:00' }] };
  const inicio = new Date('2026-01-05T11:00:00Z'); // segunda, 08:00 BRT
  const fim = new Date('2026-01-05T21:00:00Z'); // segunda, 18:00 BRT
  assert.equal(estaDentroDoHorarioPermitido({ horariosPermitidos: horario, agora: inicio }), true);
  assert.equal(estaDentroDoHorarioPermitido({ horariosPermitidos: horario, agora: fim }), true);
});
