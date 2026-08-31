'use strict';

/**
 * Estrutura de horário de acesso — configurável por aluno, por plano ou
 * por unidade, por dia da semana, com uma ou mais faixas por dia.
 * Modelo e serviço prontos pra quando os horários reais da academia
 * forem cadastrados; NENHUM horário padrão é assumido aqui — sem
 * nenhuma configuração em nenhum dos três níveis, o acesso nunca é
 * bloqueado por horário (mesmo padrão "campo ausente nunca bloqueia" já
 * usado em `proximoVencimento`/`unidadeId`).
 *
 * Formato de `horariosPermitidos` (campo esperado em `Aluno`, `Plano` ou
 * `unidades/{id}` — nenhum desses três documentos tem esse campo ainda
 * no banco real; é só o formato que esta função sabe interpretar
 * quando/se ele existir):
 *
 * ```
 * {
 *   domingo:  [{ inicio: '08:00', fim: '12:00' }],
 *   segunda:  [{ inicio: '06:00', fim: '10:00' }, { inicio: '16:00', fim: '22:00' }],
 *   terca:    [...],
 *   quarta:   [...],
 *   quinta:   [...],
 *   sexta:    [...],
 *   sabado:   [],   // vazio = fechado nesse dia
 * }
 * ```
 * Um dia ausente do objeto é tratado como "sem restrição nesse dia"
 * (nunca bloqueia) — só um array vazio explícito significa "fechado".
 */

const DIAS_DA_SEMANA = Object.freeze([
  'domingo',
  'segunda',
  'terca',
  'quarta',
  'quinta',
  'sexta',
  'sabado',
]);

const FUSO_HORARIO_PADRAO = 'America/Sao_Paulo';

/**
 * Dia da semana (nome em `DIAS_DA_SEMANA`) e horário local "HH:mm" de
 * uma data, num fuso horário específico — nunca usa o fuso local do
 * processo Node (que em Cloud Functions normalmente é UTC, o que daria
 * o dia/hora errados pra uma academia no Brasil).
 * @param {Date} data
 * @param {string} [fusoHorario]
 * @returns {{ dia: string, horaMinuto: string }}
 */
function diaEHoraLocal(data, fusoHorario) {
  fusoHorario = fusoHorario || FUSO_HORARIO_PADRAO;
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: fusoHorario,
    weekday: 'long',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(data);

  const mapa = Object.fromEntries(partes.map((p) => [p.type, p.value]));
  const diasEmIngles = {
    Sunday: 'domingo',
    Monday: 'segunda',
    Tuesday: 'terca',
    Wednesday: 'quarta',
    Thursday: 'quinta',
    Friday: 'sexta',
    Saturday: 'sabado',
  };

  // "24" as vezes vem no lugar de "00" em Intl — normaliza pra comparar
  // como string "HH:mm" de forma direta.
  const hora = mapa.hour === '24' ? '00' : mapa.hour;

  return { dia: diasEmIngles[mapa.weekday], horaMinuto: `${hora}:${mapa.minute}` };
}

/**
 * Resolve qual configuração de horário vale pra esta tentativa de
 * acesso — precedência aluno > plano > unidade > nenhuma restrição. O
 * primeiro nível que tiver `horariosPermitidos` definido (mesmo que
 * seja um objeto, ainda que todos os dias vazios) já decide sozinho;
 * não combina níveis diferentes.
 *
 * @param {{
 *   aluno?: { horariosPermitidos?: Record<string, Array<{inicio: string, fim: string}>> } | null,
 *   plano?: { horariosPermitidos?: Record<string, Array<{inicio: string, fim: string}>> } | null,
 *   unidade?: { horariosPermitidos?: Record<string, Array<{inicio: string, fim: string}>> } | null,
 * }} params
 * @returns {Record<string, Array<{inicio: string, fim: string}>> | null}
 */
function resolverHorariosPermitidos({ aluno, plano, unidade }) {
  if (aluno && aluno.horariosPermitidos) return aluno.horariosPermitidos;
  if (plano && plano.horariosPermitidos) return plano.horariosPermitidos;
  if (unidade && unidade.horariosPermitidos) return unidade.horariosPermitidos;
  return null;
}

/**
 * Verdadeiro se `agora` cai dentro de alguma faixa permitida pro dia da
 * semana correspondente — ou se `horariosPermitidos` for `null`/
 * `undefined` (sem restrição configurada, nunca bloqueia).
 *
 * @param {{
 *   horariosPermitidos: Record<string, Array<{inicio: string, fim: string}>> | null,
 *   agora: Date,
 *   fusoHorario?: string,
 * }} params
 * @returns {boolean}
 */
function estaDentroDoHorarioPermitido({ horariosPermitidos, agora, fusoHorario }) {
  if (!horariosPermitidos) return true;

  const { dia, horaMinuto } = diaEHoraLocal(agora, fusoHorario);
  const faixasDoDia = horariosPermitidos[dia];

  if (!faixasDoDia) return true; // dia ausente do objeto = sem restricao nesse dia
  if (faixasDoDia.length === 0) return false; // array vazio explicito = fechado

  return faixasDoDia.some((faixa) => horaMinuto >= faixa.inicio && horaMinuto <= faixa.fim);
}

module.exports = {
  DIAS_DA_SEMANA,
  FUSO_HORARIO_PADRAO,
  diaEHoraLocal,
  resolverHorariosPermitidos,
  estaDentroDoHorarioPermitido,
};
