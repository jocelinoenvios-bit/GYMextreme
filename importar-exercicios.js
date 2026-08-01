require('dotenv').config();
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const WORKOUTX_API_KEY = process.env.WORKOUTX_API_KEY;
if (!WORKOUTX_API_KEY) {
  console.error('Defina WORKOUTX_API_KEY no arquivo .env antes de rodar.');
  process.exit(1);
}

const WORKOUTX_BASE_URL = 'https://api.workoutxapp.com/v1';
const PAGE_SIZE = 100;
const MS_BETWEEN_REQUESTS = 2100; // fica dentro do limite de 30 req/min do plano free
const FIRESTORE_BATCH_LIMIT = 500;

const serviceAccount = require('./firebase-key.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function buscarPaginaDeExercicios(offset) {
  const url = `${WORKOUTX_BASE_URL}/exercises?limit=${PAGE_SIZE}&offset=${offset}`;
  const resposta = await fetch(url, {
    headers: { 'X-WorkoutX-Key': WORKOUTX_API_KEY },
  });

  if (!resposta.ok) {
    throw new Error(
      `WorkoutX API retornou ${resposta.status} ${resposta.statusText} (offset=${offset})`
    );
  }

  return resposta.json();
}

async function buscarTodosExercicios() {
  const todos = [];
  let offset = 0;
  let total = Infinity;

  while (offset < total) {
    const pagina = await buscarPaginaDeExercicios(offset);
    total = pagina.total ?? pagina.data.length;
    todos.push(...pagina.data);
    console.log(`Buscados ${todos.length}/${total} exercícios...`);

    offset += PAGE_SIZE;
    if (offset < total) {
      await sleep(MS_BETWEEN_REQUESTS);
    }
  }

  return todos;
}

function mapearExercicio(exercicio) {
  return {
    workoutxId: exercicio.id,
    nome: exercicio.name,
    grupoMuscular: exercicio.bodyPart,
    alvo: exercicio.target,
    equipamento: exercicio.equipment,
    nivel: exercicio.difficulty ?? null,
    instrucoes: exercicio.instructions ?? [],
    gifUrl: exercicio.gifUrl,
  };
}

async function gravarNoFirestore(exercicios) {
  const colecao = db.collection('exercicios');

  for (let i = 0; i < exercicios.length; i += FIRESTORE_BATCH_LIMIT) {
    const lote = exercicios.slice(i, i + FIRESTORE_BATCH_LIMIT);
    const batch = db.batch();

    for (const exercicio of lote) {
      const dados = mapearExercicio(exercicio);
      const docRef = colecao.doc(String(dados.workoutxId));
      batch.set(docRef, dados);
    }

    await batch.commit();
    console.log(`Gravados ${Math.min(i + FIRESTORE_BATCH_LIMIT, exercicios.length)}/${exercicios.length} no Firestore.`);
  }
}

async function main() {
  console.log('Buscando exercícios na API da WorkoutX...');
  const exercicios = await buscarTodosExercicios();

  console.log('Gravando exercícios no Firestore...');
  await gravarNoFirestore(exercicios);

  console.log(`Concluído: ${exercicios.length} exercícios importados.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Erro ao importar exercícios:', err);
    process.exit(1);
  });
