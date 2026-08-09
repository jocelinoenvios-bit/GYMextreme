import 'package:cloud_firestore/cloud_firestore.dart';

import 'permission.dart';

/// Um cargo (funcao) que pode ser atribuido a um funcionario, com um
/// conjunto de permissoes padrao que e copiado para `usuarios/{uid}.permissoes`
/// no momento do cadastro (e depois pode ser ajustado individualmente).
class Cargo {
  const Cargo({
    required this.id,
    required this.nome,
    required this.permissoesPadrao,
    required this.sistema,
  });

  /// Identificador estavel. Para os 3 cargos embutidos e uma constante de
  /// codigo (ex.: `"sistema-administrador"`); para cargos customizados e o
  /// id do documento em `cargos/{id}`.
  final String id;
  final String nome;
  final Set<Permission> permissoesPadrao;

  /// true para os cargos embutidos (Administrador/Recepcionista/Personal
  /// Trainer) — nao aparecem como editaveis/apagaveis na tela de cargos.
  final bool sistema;

  factory Cargo.fromFirestore(String id, Map<String, dynamic> data) {
    return Cargo(
      id: id,
      nome: (data['nome'] as String?)?.trim().isNotEmpty == true
          ? data['nome'] as String
          : 'Cargo sem nome',
      permissoesPadrao: Permission.setFromFirestoreValues(
        data['permissoesPadrao'] as List<dynamic>?,
      ),
      sistema: false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'permissoesPadrao': permissoesPadrao
          .map((permission) => permission.firestoreValue)
          .toList(),
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }

  // Igualdade por id: cargos customizados sao reconstruidos a cada emissao
  // do stream do Firestore, e o dropdown de selecao de cargo depende de
  // `==` pra continuar reconhecendo a opcao ja selecionada.
  @override
  bool operator ==(Object other) => other is Cargo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Os 3 cargos iniciais pedidos pelo cliente, com as permissoes padrao
/// exatamente conforme especificado. Ficam como constantes de codigo (nao
/// documentos no Firestore) para nao depender de nenhuma migracao/seed —
/// cargos criados pela propria academia no futuro (fora destes 3) e que
/// viram documentos na colecao `cargos`, combinados com estes em
/// `CargoService.watchCargos()`.
class CargosPadrao {
  CargosPadrao._();

  static final Cargo administrador = Cargo(
    id: 'sistema-administrador',
    nome: 'Administrador (Dono)',
    permissoesPadrao: Permission.values.toSet(),
    sistema: true,
  );

  static const Cargo recepcionista = Cargo(
    id: 'sistema-recepcionista',
    nome: 'Recepcionista / Caixa',
    permissoesPadrao: {
      Permission.gerenciarAlunos,
      Permission.matriculas,
      Permission.acessarPlanos,
      Permission.cadastrarPlanos,
      Permission.frequencia,
      Permission.visitantes,
      Permission.receberMensalidades,
      Permission.acessarContasReceber,
      Permission.cadastrarContasReceber,
      Permission.receberContasReceber,
      Permission.abrirCaixa,
      Permission.fecharCaixa,
      Permission.historicoPagamentos,
      Permission.emitirComprovantes,
    },
    sistema: true,
  );

  static const Cargo personalTrainer = Cargo(
    id: 'sistema-personal-trainer',
    nome: 'Personal Trainer',
    permissoesPadrao: {
      Permission.bibliotecaExercicios,
      Permission.avaliacoesFisicas,
      Permission.prescricaoTreinos,
      Permission.criarTreinos,
      Permission.editarTreinos,
      Permission.chat,
    },
    sistema: true,
  );

  static List<Cargo> get todos => [administrador, recepcionista, personalTrainer];
}
