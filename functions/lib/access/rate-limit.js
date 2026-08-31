'use strict';

/**
 * Nome da variável de ambiente que liga o guard-rail básico contra
 * flood/replay descontrolado (chamadas repetidas rápido demais do MESMO
 * dispositivo) — ver `passouIntervaloMinimo`.
 */
const VARIAVEL_INTERVALO_MINIMO_MS = 'CONTROLID_INTERVALO_MINIMO_MS';

/**
 * Lê o intervalo mínimo configurado (em milissegundos) entre duas
 * chamadas do MESMO dispositivo. Retorna `null` (desligado) se a
 * variável de ambiente não estiver configurada ou não for um número
 * válido — desligado por padrão de propósito: um valor "seguro" de
 * intervalo mínimo depende de como o iDFace realmente se comporta numa
 * catraca com fluxo real de pessoas, algo que não dá pra assumir sem
 * observar o equipamento físico. Ligar isso é uma decisão consciente de
 * configuração, nunca um padrão implícito.
 * @returns {number|null}
 */
function resolverIntervaloMinimoMs() {
  const valor = process.env[VARIAVEL_INTERVALO_MINIMO_MS];
  if (!valor) return null;
  const numero = Number(valor);
  return Number.isFinite(numero) && numero > 0 ? numero : null;
}

/**
 * Checagem pura (sem Firestore) de flood/replay: verdadeiro se já se
 * passou tempo suficiente desde a última comunicação deste dispositivo,
 * ou se o guard-rail está desligado (`intervaloMinimoMs` nulo) ou é a
 * primeira comunicação (`ultimaComunicacaoEm` nulo).
 *
 * @param {{
 *   ultimaComunicacaoEm: Date|null,
 *   agora: Date,
 *   intervaloMinimoMs: number|null,
 * }} params
 * @returns {boolean}
 */
function passouIntervaloMinimo({ ultimaComunicacaoEm, agora, intervaloMinimoMs }) {
  if (!intervaloMinimoMs) return true;
  if (!ultimaComunicacaoEm) return true;
  return agora.getTime() - ultimaComunicacaoEm.getTime() >= intervaloMinimoMs;
}

module.exports = { VARIAVEL_INTERVALO_MINIMO_MS, resolverIntervaloMinimoMs, passouIntervaloMinimo };
