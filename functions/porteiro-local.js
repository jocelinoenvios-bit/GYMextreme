'use strict';

/**
 * PORTEIRO LOCAL da catraca — roda no computador da academia, na mesma
 * rede do iDFace Pro, e faz o papel que seria da Cloud Function
 * `controlIdNewUserIdentified`, sem precisar do plano pago do Firebase:
 *
 *   iDFace reconhece o rosto ──(rede local)──> este programa
 *        └── consulta o Firebase (plano gratuito) e responde libera/nega
 *
 * Reaproveita exatamente o mesmo pipeline da versão em nuvem
 * (`processarEventoIdentificacao`, em lib/access/) — as mesmas regras de
 * liberação, o mesmo registro em `eventosAcesso`, os mesmos testes.
 *
 * Como instalar e configurar: ver PORTEIRO-LOCAL.md (passo a passo).
 *
 * Uso:  npm run porteiro
 */

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { processarEventoIdentificacao } = require('./lib/access/access-request-handler');

/** Caminho "oficial" (o mesmo da versão em nuvem, via Firebase Hosting). */
const CAMINHO_EVENTO = '/api/integrations/controlid/events/new-user-identified';

/**
 * Lê `porteiro.env` (CHAVE=valor por linha) pro process.env — sem
 * dependência extra. Variáveis já definidas no sistema têm prioridade.
 */
function carregarConfiguracao(arquivo = path.join(__dirname, 'porteiro.env')) {
  if (!fs.existsSync(arquivo)) return;
  for (const linha of fs.readFileSync(arquivo, 'utf8').split(/\r?\n/)) {
    const limpa = linha.trim();
    if (!limpa || limpa.startsWith('#')) continue;
    const igual = limpa.indexOf('=');
    if (igual < 0) continue;
    const chave = limpa.slice(0, igual).trim();
    let valor = limpa.slice(igual + 1).trim();
    if (/^(['"]).*\1$/.test(valor)) valor = valor.slice(1, -1);
    if (process.env[chave] === undefined) process.env[chave] = valor;
  }
}

/**
 * O iDFace no "Modo Online" pode chamar o caminho configurado inteiro ou
 * só o nome do evento no fim (`.../new_user_identified.fcgi`) — A
 * CONFIRMAR NO EQUIPAMENTO; aceita os dois.
 */
function ehEventoDeIdentificacao(caminho) {
  return caminho === CAMINHO_EVENTO || caminho.endsWith('/new_user_identified.fcgi');
}

function lerCorpo(req, limiteBytes = 256 * 1024) {
  return new Promise((resolve, reject) => {
    const partes = [];
    let total = 0;
    req.on('data', (parte) => {
      total += parte.length;
      if (total > limiteBytes) {
        reject(new Error('corpo grande demais'));
        req.destroy();
        return;
      }
      partes.push(parte);
    });
    req.on('end', () => resolve(Buffer.concat(partes).toString('utf8')));
    req.on('error', reject);
  });
}

function responderJson(res, status, corpo) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(corpo));
}

function hora() {
  return new Date().toLocaleTimeString('pt-BR');
}

/**
 * Monta o servidor HTTP. Separado de `iniciar()` pra os testes subirem o
 * mesmo servidor contra o Firestore Emulator.
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {{ log?: (linha: string) => void }} [opcoes]
 */
function criarServidor(db, { log = console.log } = {}) {
  let atendidos = 0;
  let ultimo = null;

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://porteiro.local');
    const caminho = url.pathname;

    // Página de conferência: abrir http://IP-DO-COMPUTADOR:PORTA no
    // navegador mostra se o porteiro está no ar.
    if (req.method === 'GET' && (caminho === '/' || caminho === '/status')) {
      responderJson(res, 200, {
        porteiro: 'GYM XTREME',
        funcionando: true,
        eventosAtendidos: atendidos,
        ultimoEvento: ultimo,
      });
      return;
    }

    // "Estou vivo" do aparelho — só confirma.
    if (caminho.endsWith('/device_is_alive.fcgi')) {
      responderJson(res, 200, {});
      return;
    }

    if (!ehEventoDeIdentificacao(caminho)) {
      responderJson(res, 404, { error: 'not_found' });
      return;
    }
    if (req.method !== 'POST') {
      responderJson(res, 405, { error: 'method_not_allowed' });
      return;
    }

    let payload = null;
    try {
      const texto = await lerCorpo(req);
      payload = texto ? JSON.parse(texto) : null;
    } catch (_) {
      payload = null; // o pipeline responde 400 pra payload inutilizável
    }

    const deviceToken = req.headers['x-device-token'] || url.searchParams.get('token') || null;

    try {
      const { httpStatus, corpo } = await processarEventoIdentificacao(db, { payload, deviceToken });
      atendidos++;
      const resultado = corpo && corpo.result;
      ultimo = {
        hora: hora(),
        userId: resultado ? resultado.user_id : null,
        liberado: resultado ? resultado.event === 7 : false,
      };
      log(
        `[${ultimo.hora}] ${ultimo.liberado ? 'LIBERADO' : 'NEGADO  '} ` +
          `user_id=${ultimo.userId ?? '-'}${resultado && resultado.message ? ` (${resultado.message})` : ''}`,
      );
      responderJson(res, httpStatus, corpo || { error: 'invalid_payload' });
    } catch (erro) {
      // processarEventoIdentificacao já nega e registra qualquer erro
      // interno; isto só pega falha antes disso (ex.: sem internet).
      log(`[${hora()}] ERRO: ${erro && erro.message ? erro.message : erro}`);
      responderJson(res, 500, { error: 'internal' });
    }
  });
}

function iniciar() {
  carregarConfiguracao();

  const chave = process.env.CHAVE_FIREBASE;
  if (!chave || !fs.existsSync(chave)) {
    console.error(
      'Arquivo da chave do Firebase não encontrado.\n' +
        'Coloque o caminho dele em CHAVE_FIREBASE, no arquivo porteiro.env ' +
        '(ver PORTEIRO-LOCAL.md, passo 3).',
    );
    process.exit(1);
  }

  const { initializeApp, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(chave, 'utf8'))) });
  const db = getFirestore();

  const porta = Number(process.env.PORTA || 8080);
  criarServidor(db).listen(porta, () => {
    console.log(`Porteiro GYM XTREME no ar, na porta ${porta}.`);
    console.log('Deixe esta janela aberta. Para conferir, abra no navegador:');
    console.log(`  http://localhost:${porta}`);
  });
}

if (require.main === module) {
  iniciar();
}

module.exports = { criarServidor, carregarConfiguracao, ehEventoDeIdentificacao, CAMINHO_EVENTO };
