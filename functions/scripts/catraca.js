'use strict';

/**
 * Comandos de configuração da catraca, pra rodar no computador da academia
 * (mesma chave do Firebase do porteiro — ver PORTEIRO-LOCAL.md).
 *
 *   npm run catraca -- cadastrar-dispositivo "Entrada principal"
 *   npm run catraca -- listar-dispositivos
 *   npm run catraca -- configurar-abertura <idDoDispositivo> '<json das ações>'
 *   npm run catraca -- vincular <idDoDispositivo> <codigoNoIdface> <email-do-aluno>
 *   npm run catraca -- desvincular <idDoDispositivo> <codigoNoIdface>
 *
 * Vincular aluno também dá pra fazer pelo app (ficha do aluno → aba Frequência → Catraca).
 */

const fs = require('node:fs');
const { carregarConfiguracao } = require('../porteiro-local');
const {
  cadastrarDispositivo,
  configurarAcoesAbertura,
  vincularCredencial,
  desvincularCredencial,
} = require('../lib/access/device-sync-service');

const UNIDADE_PADRAO = 'principal';

function conectar() {
  carregarConfiguracao();
  const chave = process.env.CHAVE_FIREBASE;
  if (!chave || !fs.existsSync(chave)) {
    console.error('Configure CHAVE_FIREBASE no porteiro.env (ver PORTEIRO-LOCAL.md, passo 3).');
    process.exit(1);
  }
  const { initializeApp, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(chave, 'utf8'))) });
  return getFirestore();
}

async function garantirUnidadePadrao(db) {
  const ref = db.collection('unidades').doc(UNIDADE_PADRAO);
  if (!(await ref.get()).exists) await ref.set({ nome: 'Principal' });
}

async function alunoPorEmail(db, email) {
  const snap = await db
    .collection('usuarios')
    .where('email', '==', email.trim())
    .where('role', '==', 'aluno')
    .limit(1)
    .get();
  if (snap.empty) throw new Error(`Nenhum aluno com o e-mail ${email}.`);
  const doc = snap.docs[0];
  return { uid: doc.id, nome: doc.data().nome };
}

async function main(argv) {
  const [comando, ...args] = argv;
  if (!comando) {
    const ajuda = fs.readFileSync(__filename, 'utf8').split('*/')[0].split('/**')[1];
    console.log(ajuda.replace(/^ \* ?/gm, ''));
    return;
  }
  const db = conectar();

  switch (comando) {
    case 'cadastrar-dispositivo': {
      await garantirUnidadePadrao(db);
      const { deviceId, token } = await cadastrarDispositivo(db, {
        unidadeId: UNIDADE_PADRAO,
        tipo: 'idface_pro',
        nome: args[0] || 'iDFace',
      });
      console.log('Dispositivo cadastrado.');
      console.log(`  id:    ${deviceId}`);
      console.log(`  token: ${token}`);
      console.log('Anote o token AGORA: ele não aparece de novo (só o resumo dele fica salvo).');
      console.log('Ele vai na configuração do iDFace (ver PORTEIRO-LOCAL.md, passo 6).');
      return;
    }
    case 'listar-dispositivos': {
      const snap = await db.collection('dispositivosAcesso').get();
      if (snap.empty) console.log('Nenhum dispositivo cadastrado.');
      for (const doc of snap.docs) {
        const d = doc.data();
        const vinculos = await doc.ref.collection('credenciais').count().get();
        console.log(
          `${doc.id}  ${d.nome || '-'}  ${d.ativo ? 'ativo' : 'INATIVO'}  ` +
            `${vinculos.data().count} aluno(s) vinculado(s)`,
        );
      }
      return;
    }
    case 'configurar-abertura': {
      const [deviceId, json] = args;
      await configurarAcoesAbertura(db, { deviceId, acoes: JSON.parse(json) });
      console.log('Ação de abertura salva.');
      return;
    }
    case 'vincular': {
      const [deviceId, codigo, email] = args;
      if (!deviceId || !codigo || !email) throw new Error('Uso: vincular <idDoDispositivo> <codigoNoIdface> <email-do-aluno>');
      const aluno = await alunoPorEmail(db, email);
      await vincularCredencial(db, { deviceId, userIdDispositivo: String(codigo), alunoUid: aluno.uid });
      console.log(`Código ${codigo} vinculado a ${aluno.nome}.`);
      return;
    }
    case 'desvincular': {
      const [deviceId, codigo] = args;
      await desvincularCredencial(db, { deviceId, userIdDispositivo: String(codigo) });
      console.log(`Código ${codigo} desvinculado.`);
      return;
    }
    default:
      throw new Error(`Comando desconhecido: ${comando}`);
  }
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((erro) => {
    console.error(erro.message || erro);
    process.exit(1);
  });
}

module.exports = { main, alunoPorEmail, garantirUnidadePadrao };
