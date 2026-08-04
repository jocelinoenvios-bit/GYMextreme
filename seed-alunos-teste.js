// Cria alunos de teste completos (dados, anamnese, termo aceito, historico
// de avaliacoes e ficha de treino) direto no Firestore/Auth, pra validar o
// Modulo 2 sem preencher o wizard na mao repetidas vezes.
//
// Precisa do `firebase-key.json` (Firebase Console > Configuracoes do
// projeto > Contas de servico > Gerar nova chave privada) salvo na raiz
// do projeto. Esse arquivo já está no .gitignore — nunca commite.
//
// Uso:
//   npm install        (só na primeira vez; já usa as deps do projeto)
//   node seed-alunos-teste.js
//
// Cada aluno de teste recebe uma conta de login de verdade (e-mail/senha
// impressos no final) — dá pra logar como aluno e ver a ficha pelo lado
// dele também, não só pelo lado da recepção/personal.

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const serviceAccount = require('./firebase-key.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
const auth = getAuth();

const SENHA_PADRAO = 'teste123';
const CADASTRADO_POR_UID = 'seed-script';
const CADASTRADO_POR_NOME = 'Script de teste (seed-alunos-teste.js)';

function diasAtras(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
}

const ALUNOS_TESTE = [
  {
    nome: 'Mariana Costa Lima',
    email: 'mariana.teste@gymextreme.dev',
    sexo: 'feminino',
    dataNascimento: new Date(1996, 4, 12),
    cpf: '111.111.111-11',
    rg: '11.111.111-1',
    telefone: '(88) 99111-1111',
    whatsapp: '(88) 99111-1111',
    endereco: {
      cep: '62000-000',
      logradouro: 'Rua das Flores',
      numero: '120',
      complemento: 'Apto 3',
      bairro: 'Centro',
      cidade: 'Sobral',
      uf: 'CE',
    },
    contatoEmergenciaNome: 'Pai - José Costa',
    contatoEmergenciaTelefone: '(88) 99222-2222',
    observacoes: 'Aluna de teste — perfil hipertrofia, sem restrições.',
    dataInicio: diasAtras(90),
    diaVencimento: 5,
    anamnese: {
      diasPorSemana: 5,
      objetivo: 'hipertrofia',
      situacaoMusculacao: 'sim',
      problemaColunaJoelho: false,
      pressaoArterial: 'normal',
      condicoesClinicas: ['nenhum'],
      alergia: false,
      doresCorpo: false,
      lesaoOsteoMuscular: false,
      cirurgiaRecente: false,
      usaMedicamento: false,
      usoSubstancias: ['nao'],
      fazendoDieta: true,
      dietaPorContaPropria: false,
      dietaOrientacaoNutricionista: true,
    },
    avaliacoes: [
      { diasAtras: 60, pesoKg: 68.4, alturaM: 1.65, cintura: 74, peito: 90, gluteo: 98 },
      { diasAtras: 5, pesoKg: 65.9, alturaM: 1.65, cintura: 70, peito: 91, gluteo: 97 },
    ],
    treinos: [
      { letra: 'A', nome: 'Treino A', grupoMuscular: 'Peito e tríceps', qtdExercicios: 3 },
      { letra: 'B', nome: 'Treino B', grupoMuscular: 'Costas e bíceps', qtdExercicios: 3 },
    ],
  },
  {
    nome: 'Rafael Souza Almeida',
    email: 'rafael.teste@gymextreme.dev',
    sexo: 'masculino',
    dataNascimento: new Date(1988, 10, 3),
    cpf: '222.222.222-22',
    rg: '22.222.222-2',
    telefone: '(88) 99333-3333',
    whatsapp: '(88) 99333-3333',
    endereco: {
      cep: '62010-000',
      logradouro: 'Av. Beira Mar',
      numero: '450',
      complemento: '',
      bairro: 'Dom Expedito',
      cidade: 'Sobral',
      uf: 'CE',
    },
    contatoEmergenciaNome: 'Esposa - Camila Almeida',
    contatoEmergenciaTelefone: '(88) 99444-4444',
    observacoes: 'Aluno de teste — indicação médica, controlar pressão.',
    dataInicio: diasAtras(20),
    diaVencimento: 15,
    anamnese: {
      diasPorSemana: 3,
      objetivo: 'indicacaoMedica',
      situacaoMusculacao: 'nuncaFez',
      problemaColunaJoelho: true,
      problemaColunaJoelhoQual: 'Dor lombar leve ao carregar peso',
      pressaoArterial: 'alta',
      condicoesClinicas: ['hipertenso'],
      alergia: false,
      doresCorpo: true,
      doresCorpoQual: 'Lombar, esporádica',
      lesaoOsteoMuscular: false,
      cirurgiaRecente: false,
      usaMedicamento: true,
      usaMedicamentoQual: 'Losartana 50mg',
      usoSubstancias: ['nao'],
      fazendoDieta: false,
    },
    avaliacoes: [
      { diasAtras: 18, pesoKg: 91.2, alturaM: 1.78, cintura: 98, peito: 102, gluteo: 104 },
    ],
    treinos: [
      { letra: 'A', nome: 'Treino A - Adaptação', grupoMuscular: 'Corpo inteiro (baixo impacto)', qtdExercicios: 4 },
    ],
  },
  {
    nome: 'Juliana Pereira Rocha',
    email: 'juliana.teste@gymextreme.dev',
    sexo: 'feminino',
    dataNascimento: new Date(2003, 1, 27),
    cpf: '333.333.333-33',
    rg: '33.333.333-3',
    telefone: '(88) 99555-5555',
    whatsapp: '(88) 99555-5555',
    endereco: {
      cep: '62020-000',
      logradouro: 'Rua Coronel José Lima',
      numero: '78',
      complemento: '',
      bairro: 'Junco',
      cidade: 'Sobral',
      uf: 'CE',
    },
    contatoEmergenciaNome: 'Mãe - Rosa Rocha',
    contatoEmergenciaTelefone: '(88) 99666-6666',
    observacoes: '',
    dataInicio: diasAtras(2),
    diaVencimento: 20,
    // Cadastro recente, ainda sem anamnese/avaliação/treino — pra testar o
    // caminho de uma ficha incompleta (aluno recém-chegado da recepção).
    anamnese: null,
    avaliacoes: [],
    treinos: [],
  },
];

// Ids reais da Biblioteca Oficial de Exercícios (ExerciseDB, empacotada
// como asset local do app — não fica na coleção "exercicios" do
// Firestore, então não há nada pra consultar aqui). Bastam ids válidos;
// nome/gif/instruções são sempre resolvidos pelo app a partir do id.
const EXERCICIOS_BIBLIOTECA_OFICIAL = [
  '0001', '0002', '0003', '0006', '0007', '0009', '0010', '0011', '0012', '0013',
];

function pegarExerciciosDisponiveis(qtd) {
  return EXERCICIOS_BIBLIOTECA_OFICIAL.slice(0, qtd).map((id) => ({ id }));
}

async function criarOuReaproveitarConta(email, nome) {
  try {
    const existente = await auth.getUserByEmail(email);
    console.log(`  já existia (reaproveitando): ${email}`);
    return existente.uid;
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
  }
  const criado = await auth.createUser({ email, password: SENHA_PADRAO, displayName: nome });
  return criado.uid;
}

function montarTreino(config, exerciciosDisponiveis) {
  const exercicios = exerciciosDisponiveis.slice(0, config.qtdExercicios).map((ex, i) => ({
    exercicioId: ex.id,
    series: 4,
    repeticoes: i === 0 ? '10-12' : '8-10',
    cargaKg: 20 + i * 5,
    descansoSegundos: 60,
    observacoes: null,
    ordem: i,
  }));

  return {
    nome: config.nome,
    letra: config.letra,
    grupoMuscular: config.grupoMuscular,
    ordem: 0,
    ativo: true,
    exercicios,
    criadoPorUid: CADASTRADO_POR_UID,
    criadoPorNome: CADASTRADO_POR_NOME,
    criadoEm: FieldValue.serverTimestamp(),
    atualizadoPorUid: CADASTRADO_POR_UID,
    atualizadoPorNome: CADASTRADO_POR_NOME,
    atualizadoEm: FieldValue.serverTimestamp(),
  };
}

async function seedAluno(config, exerciciosDisponiveis) {
  console.log(`\nCriando: ${config.nome} (${config.email})`);
  const uid = await criarOuReaproveitarConta(config.email, config.nome);

  await db.collection('usuarios').doc(uid).set({
    nome: config.nome,
    email: config.email,
    role: 'aluno',
    criadoEm: FieldValue.serverTimestamp(),
    permissoes: [],
  });

  const alunoDoc = {
    sexo: config.sexo,
    dataNascimento: Timestamp.fromDate(config.dataNascimento),
    idade: null,
    fotoUrl: null,
    cpf: config.cpf,
    rg: config.rg,
    telefone: config.telefone,
    whatsapp: config.whatsapp,
    endereco: config.endereco,
    contatoEmergenciaNome: config.contatoEmergenciaNome,
    contatoEmergenciaTelefone: config.contatoEmergenciaTelefone,
    observacoes: config.observacoes || null,
    dataInicio: Timestamp.fromDate(config.dataInicio),
    diaVencimento: config.diaVencimento,
    cadastradoPorUid: CADASTRADO_POR_UID,
    cadastradoPorNome: CADASTRADO_POR_NOME,
  };

  if (config.anamnese) {
    alunoDoc.anamnese = { ...config.anamnese, respondidoEm: FieldValue.serverTimestamp() };
  }

  alunoDoc.termo = config.anamnese
    ? {
        aceito: true,
        aceitoEm: FieldValue.serverTimestamp(),
        nomeAssinatura: config.nome,
        responsavel: null,
        versaoRegulamento: '2026-08',
        registradoPorUid: CADASTRADO_POR_UID,
        registradoPorNome: CADASTRADO_POR_NOME,
      }
    : { aceito: false };

  await db.collection('alunos').doc(uid).set(alunoDoc, { merge: true });
  console.log('  cadastro + anamnese + termo gravados.');

  for (const av of config.avaliacoes) {
    await db.collection('alunos').doc(uid).collection('avaliacoes').add({
      data: Timestamp.fromDate(diasAtras(av.diasAtras)),
      pesoKg: av.pesoKg,
      alturaM: av.alturaM,
      circunferenciasCm: {
        pescoco: null, ombro: null, peito: av.peito ?? null,
        bracoDRelaxado: null, bracoERelaxado: null,
        bracoDContraido: null, bracoEContraido: null,
        antebracoD: null, antebracoE: null,
        cintura: av.cintura ?? null, abdomen: null,
        gluteo: av.gluteo ?? null,
        coxaProximalD: null, coxaProximalE: null,
        panturrilhaD: null, panturrilhaE: null,
      },
      observacoes: null,
      fotoUrls: [],
      criadoEm: FieldValue.serverTimestamp(),
    });
  }
  if (config.avaliacoes.length) {
    console.log(`  ${config.avaliacoes.length} avaliação(ões) física(s) gravada(s).`);
  }

  for (const t of config.treinos) {
    await db.collection('alunos').doc(uid).collection('treinos').add(
      montarTreino(t, exerciciosDisponiveis)
    );
  }
  if (config.treinos.length) {
    console.log(`  ${config.treinos.length} ficha(s) de treino gravada(s).`);
  }

  return { nome: config.nome, email: config.email, senha: SENHA_PADRAO };
}

async function main() {
  const exerciciosDisponiveis = pegarExerciciosDisponiveis(10);

  const criados = [];
  for (const config of ALUNOS_TESTE) {
    criados.push(await seedAluno(config, exerciciosDisponiveis));
  }

  console.log('\n=== Contas de teste prontas para login (role: aluno) ===');
  for (const c of criados) {
    console.log(`  ${c.nome.padEnd(28)} ${c.email.padEnd(30)} senha: ${c.senha}`);
  }
  console.log('\nAbra "Gerenciar alunos" no app (logado como ADM/recepção) pra ver as fichas.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Erro ao criar alunos de teste:', err);
    process.exit(1);
  });
