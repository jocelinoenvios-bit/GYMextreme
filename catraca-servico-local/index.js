'use strict';

require('dotenv').config();
const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const {
  getFirestore,
  collection,
  query,
  where,
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp,
} = require('firebase/firestore');

// ~1s pedido — trava por software. Recomenda-se TAMBEM um corte por
// hardware (rele/timer monostavel), pra um crash deste processo nunca
// deixar o solenoide energizado indefinidamente. Ver README.md.
const PULSO_MS = 1000;

function precisa(nome) {
  const valor = process.env[nome];
  if (!valor) {
    console.error(`Defina ${nome} no arquivo .env antes de rodar (ver .env.example).`);
    process.exit(1);
  }
  return valor;
}

const firebaseConfig = {
  apiKey: precisa('FIREBASE_API_KEY'),
  authDomain: precisa('FIREBASE_AUTH_DOMAIN'),
  projectId: precisa('FIREBASE_PROJECT_ID'),
  appId: precisa('FIREBASE_APP_ID'),
};
const academiaId = precisa('CATRACA_ACADEMIA_ID');
const email = precisa('CATRACA_EMAIL');
const senha = precisa('CATRACA_SENHA');

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

/**
 * Unico ponto de todo o sistema que toca o hardware da catraca. Ainda nao
 * ligado a nenhum rele/controlador especifico — isso depende do hardware
 * escolhido (rele USB, Arduino/ESP32 por serial, GPIO de um Raspberry Pi
 * etc.), decisao em aberto na arquitetura publicada.
 */
async function acionarSolenoide() {
  console.log('[hardware] TODO: enviar pulso real pro solenoide aqui.');
  // Exemplos de onde isso entraria, dependendo do hardware escolhido:
  //   - Rele USB (HID):        const { HID } = require('node-hid');
  //   - Arduino/ESP32 (serial): const { SerialPort } = require('serialport');
  //   - GPIO de Raspberry Pi:   const { Gpio } = require('onoff');
  await new Promise((resolve) => setTimeout(resolve, PULSO_MS));
  console.log(
    '[hardware] TODO: desligar o pulso aqui (mesmo que o hardware tenha corte proprio).',
  );
}

async function processarAutorizacao(snap) {
  const dados = snap.data();
  const agora = new Date();
  const expirada = dados.expiraEm && dados.expiraEm.toDate() < agora;

  if (expirada) {
    console.log(`[${snap.id}] autorizacao expirada, ignorando (evita replay).`);
  } else if (dados.autorizado) {
    console.log(`[${snap.id}] autorizado — aluno ${dados.alunoUid}. Acionando catraca...`);
    await acionarSolenoide();
    console.log(`[${snap.id}] catraca liberada.`);
  } else {
    console.log(`[${snap.id}] negado — motivo: ${dados.motivoNegacao}.`);
  }

  await updateDoc(doc(db, 'academias', academiaId, 'autorizacoesAcesso', snap.id), {
    consumida: true,
    processadoEm: serverTimestamp(),
  });
}

async function main() {
  await signInWithEmailAndPassword(auth, email, senha);
  console.log(`Autenticado. Escutando autorizações de acesso da academia "${academiaId}"...`);

  const fila = query(
    collection(db, 'academias', academiaId, 'autorizacoesAcesso'),
    where('consumida', '==', false),
  );

  onSnapshot(fila, (snapshot) => {
    snapshot.docChanges().forEach((change) => {
      if (change.type === 'added') {
        processarAutorizacao(change.doc).catch((err) =>
          console.error(`Erro processando ${change.doc.id}:`, err),
        );
      }
    });
  });
}

main().catch((err) => {
  console.error('Erro ao iniciar o serviço local da catraca:', err);
  process.exit(1);
});
