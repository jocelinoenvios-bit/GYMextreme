import 'mensalidade.dart';

/// Texto do "REGULAMENTO" da ficha em papel — e o TERMO DE
/// RESPONSABILIDADE citado na propria regra 07. Versionado porque, se o
/// texto mudar no futuro, aceites antigos devem continuar validos para a
/// versao que a pessoa realmente leu.
const String regulamentoVersaoAtual = '2026-08-03';

List<String> get regulamentoRegras => [
  'A mensalidade é pessoal e intransferível.',
  'Não haverá devolução de mensalidade.',
  'Após o vencimento, daremos uma tolerância de '
      '$toleranciaMensalidadeDias dias para a renovação da mensalidade. '
      'Depois desse prazo, o acesso ao aplicativo e à academia fica '
      'suspenso até a regularização do pagamento.',
  'Caso o aluno não renove sua mensalidade, terá que comunicar a direção '
      'da academia.',
  'Caso o aluno queira mudar seu vencimento, terá que pagar a diferença '
      'dos dias.',
  'O tempo nas esteiras, bicicletas, elípticos e step será determinado '
      'pelo professor.',
  'O aluno não poderá modificar exercícios prescritos na ficha de treino.',
  'O aluno, maior de idade, que for treinar por conta própria, terá que '
      'assinar este Termo de Responsabilidade.',
  'A academia não se responsabiliza por qualquer objeto esquecido em seu '
      'interior, bem como carros, bicicletas ou motos estacionados nas '
      'ruas.',
  'Alunos que fizerem cirurgias recentes, principalmente mulheres '
      'pós-parto, terão que trazer autorização por escrito do seu médico.',
  'Não será permitida a entrada de crianças na sala de musculação.',
  'O aluno que danificar algum objeto da academia pagará pelo mesmo.',
  'Não é permitido treinar sem o uso de tênis.',
  'Por questão de higiene pessoal, aconselhamos que o aluno traga sua '
      'toalha.',
  'Todo aluno terá que retirar os pesos das máquinas, bem como guardar '
      'caneleiras e colchonetes em seus devidos lugares.',
];
