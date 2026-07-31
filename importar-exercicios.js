const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./firebase-key.json');
const exercicios = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'exercicios.json'), 'utf8')
);

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function importarExercicios() {
  const batch = db.batch();
  const colecao = db.collection('exercicios');

  for (const exercicio of exercicios) {
    const docRef = colecao.doc();
    batch.set(docRef, exercicio);
  }

  await batch.commit();
  console.log(`${exercicios.length} exercícios importados com sucesso.`);
}

importarExercicios()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Erro ao importar exercícios:', err);
    process.exit(1);
  });
