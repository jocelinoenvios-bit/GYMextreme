import '../models/exercise_model.dart';

/// Fonte de dados da tela de execução do exercício. A UI depende só
/// disto — nunca de Firestore, nem de uma API, diretamente.
///
/// Quando a Biblioteca de Exercícios oficial (ou uma API externa) for
/// integrada, criar uma nova implementação (ex.: `FirestoreExerciseRepository`
/// ou `BibliotecaApiExerciseRepository`) que busca da fonte real e monta
/// `ExercisePrescription`/`ExerciseModel` — a tela não muda uma linha.
abstract class ExerciseRepository {
  /// Exercícios prescritos pra uma sessão de execução, na ordem em que
  /// devem ser executados.
  Future<List<ExercisePrescription>> buscarExerciciosDoTreino(String treinoId);
}

/// Implementação com dados mock/placeholder — usada até a fonte real
/// existir. `treinoId` é ignorado de propósito (mesma lista pra
/// qualquer id), já que o objetivo aqui é só validar a interface.
class MockExerciseRepository implements ExerciseRepository {
  const MockExerciseRepository();

  @override
  Future<List<ExercisePrescription>> buscarExerciciosDoTreino(String treinoId) async {
    // Simula a latência de uma leitura real, pra tela já nascer
    // preparada pra um estado de carregamento.
    await Future.delayed(const Duration(milliseconds: 400));
    return _exerciciosMock;
  }
}

const _voadorMaquina = ExerciseModel(
  id: 'peck-deck',
  nome: 'Voador na Máquina',
  grupoMuscular: 'Peito',
  gifUrl: 'placeholder://exercicios/peck-deck-frontal.gif',
  gifUrlLateral: 'placeholder://exercicios/peck-deck-lateral.gif',
  musculosPrincipais: ['Peitoral maior'],
  musculosAuxiliares: ['Deltoide anterior'],
  passoAPasso: [
    'Ajuste o banco: punhos na altura dos ombros',
    'Segure as alças com os cotovelos levemente flexionados',
    'Leve os braços à frente até se tocarem na linha do peito',
    'Retorne controladamente até sentir o alongamento do peitoral',
  ],
  respiracao: 'Expire ao fechar os braços (fase concêntrica); inspire ao abrir (fase excêntrica).',
  amplitude: 'Abra até sentir alongamento leve no peito, sem forçar o ombro para trás.',
  errosComuns: [
    'Usar impulso do tronco',
    'Abrir demais os braços forçando os ombros',
    'Carga excessiva que impede o controle do movimento',
  ],
  cuidados: 'Evite hiperextensão do ombro. Pare se sentir dor articular, não muscular.',
  ajusteMaquina: 'Altura do banco = punhos alinhados aos ombros.',
);

const _remadaBaixa = ExerciseModel(
  id: 'remada-baixa',
  nome: 'Remada Baixa',
  grupoMuscular: 'Costas',
  gifUrl: 'placeholder://exercicios/remada-baixa-frontal.gif',
  musculosPrincipais: ['Latíssimo do dorso', 'Trapézio médio'],
  musculosAuxiliares: ['Bíceps'],
  passoAPasso: [
    'Sente-se com os pés apoiados e os joelhos levemente flexionados',
    'Puxe a barra até o abdômen, cotovelos próximos ao corpo',
    'Controle a volta até o braço estender por completo',
  ],
  respiracao: 'Expire ao puxar; inspire ao voltar.',
  amplitude: 'Puxe até o abdômen, sem inclinar o tronco pra trás pra "ajudar".',
  errosComuns: ['Balançar o tronco pra ganhar impulso', 'Encolher os ombros durante a puxada'],
  cuidados: 'Mantenha a coluna neutra — evite arredondar as costas no retorno.',
  ajusteMaquina: 'Apoio dos pés na altura confortável pros joelhos ficarem levemente flexionados.',
);

const _agachamentoLivre = ExerciseModel(
  id: 'agachamento-livre',
  nome: 'Agachamento Livre',
  grupoMuscular: 'Pernas',
  gifUrl: 'placeholder://exercicios/agachamento-livre-frontal.gif',
  musculosPrincipais: ['Quadríceps', 'Glúteos'],
  musculosAuxiliares: ['Posterior de coxa', 'Core'],
  passoAPasso: [
    'Pés na largura dos ombros, barra apoiada no trapézio',
    'Desça flexionando quadril e joelhos ao mesmo tempo',
    'Desça até a coxa ficar paralela ao chão (ou seu limite de mobilidade)',
    'Suba empurrando o chão com os pés',
  ],
  respiracao: 'Inspire e prenda o ar levemente na descida; expire na subida.',
  amplitude: 'Desça o quanto sua mobilidade permitir sem tirar o calcanhar do chão.',
  errosComuns: ['Joelhos "caindo" pra dentro', 'Tirar o calcanhar do chão', 'Arredondar a lombar'],
  cuidados: 'Se sentir dor no joelho (não desconforto muscular), pare e ajuste a amplitude.',
);

final List<ExercisePrescription> _exerciciosMock = [
  const ExercisePrescription(
    exercise: _voadorMaquina,
    series: 3,
    repeticoes: '12',
    cargaKg: 18,
    descansoSegundos: 60,
    observacoesPersonal: 'Foco na fase excêntrica — desça em 3 segundos.',
  ),
  const ExercisePrescription(
    exercise: _remadaBaixa,
    series: 3,
    repeticoes: '10-12',
    cargaKg: 40,
    descansoSegundos: 60,
  ),
  const ExercisePrescription(
    exercise: _agachamentoLivre,
    series: 4,
    repeticoes: '8',
    cargaKg: 50,
    descansoSegundos: 90,
    observacoesPersonal: 'Sem pressa — controle a descida.',
  ),
];
