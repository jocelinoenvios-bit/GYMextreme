/// Categorias usadas para agrupar as permissoes na tela de gestao de
/// funcionarios (uma secao de checkboxes por categoria).
enum PermissaoCategoria {
  alunos('Alunos e Atendimento'),
  treino('Treino'),
  financeiro('Financeiro'),
  sistema('Sistema');

  const PermissaoCategoria(this.label);

  final String label;
}

/// Catalogo completo de permissoes do GymExtreme.
///
/// Cobre tanto os modulos que ja existem no app (gerenciarAlunos,
/// bibliotecaExercicios, avaliacoesFisicas) quanto os que ainda serao
/// construidos (financeiro, turmas, catraca etc.) — assim, quando um modulo
/// novo for implementado, basta usar [PermissionService.has] com o valor
/// correspondente, sem precisar mexer nesta arquitetura de novo.
///
/// O valor gravado no Firestore (campo `permissoes` da colecao `usuarios`)
/// e sempre o de [Permission.firestoreValue] (o nome do enum).
enum Permission {
  // Alunos e atendimento
  gerenciarAlunos(PermissaoCategoria.alunos, 'Gerenciar alunos'),
  cadastrarAlunos(PermissaoCategoria.alunos, 'Cadastrar alunos'),
  editarAlunos(PermissaoCategoria.alunos, 'Editar alunos'),
  excluirAlunos(PermissaoCategoria.alunos, 'Excluir alunos'),
  matriculas(PermissaoCategoria.alunos, 'Matrículas'),
  acessarPlanos(PermissaoCategoria.alunos, 'Acessar planos'),
  cadastrarPlanos(PermissaoCategoria.alunos, 'Cadastrar planos'),
  alterarPlanos(PermissaoCategoria.alunos, 'Alterar planos'),
  excluirPlanos(PermissaoCategoria.alunos, 'Excluir planos'),
  frequencia(PermissaoCategoria.alunos, 'Controle de frequência'),
  turmas(PermissaoCategoria.alunos, 'Turmas'),
  visitantes(PermissaoCategoria.alunos, 'Visitantes'),

  // Treino
  bibliotecaExercicios(PermissaoCategoria.treino, 'Biblioteca de exercícios'),
  avaliacoesFisicas(PermissaoCategoria.treino, 'Avaliações físicas'),
  prescricaoTreinos(PermissaoCategoria.treino, 'Prescrição de treinos'),
  criarTreinos(PermissaoCategoria.treino, 'Criar treinos'),
  editarTreinos(PermissaoCategoria.treino, 'Editar treinos'),
  chat(PermissaoCategoria.treino, 'Chat'),

  // Financeiro
  financeiro(PermissaoCategoria.financeiro, 'Financeiro'),
  acessarContasPagar(PermissaoCategoria.financeiro, 'Acessar contas a pagar'),
  cadastrarContasPagar(PermissaoCategoria.financeiro, 'Cadastrar contas a pagar'),
  alterarContasPagar(PermissaoCategoria.financeiro, 'Alterar contas a pagar'),
  excluirContasPagar(PermissaoCategoria.financeiro, 'Excluir contas a pagar'),
  pagarContasPagar(PermissaoCategoria.financeiro, 'Pagar contas a pagar'),
  acessarContasReceber(PermissaoCategoria.financeiro, 'Acessar contas a receber'),
  cadastrarContasReceber(PermissaoCategoria.financeiro, 'Cadastrar contas a receber'),
  alterarContasReceber(PermissaoCategoria.financeiro, 'Alterar contas a receber'),
  excluirContasReceber(PermissaoCategoria.financeiro, 'Excluir contas a receber'),
  receberContasReceber(PermissaoCategoria.financeiro, 'Receber contas a receber'),
  acessarProdutos(PermissaoCategoria.financeiro, 'Acessar produtos'),
  cadastrarProdutos(PermissaoCategoria.financeiro, 'Cadastrar produtos'),
  alterarProdutos(PermissaoCategoria.financeiro, 'Alterar produtos'),
  excluirProdutos(PermissaoCategoria.financeiro, 'Excluir produtos'),
  acessarEstoque(PermissaoCategoria.financeiro, 'Acessar estoque'),
  movimentarEstoque(PermissaoCategoria.financeiro, 'Movimentar estoque'),
  acessarControleCaixa(PermissaoCategoria.financeiro, 'Acessar controle de caixa'),
  abrirCaixa(PermissaoCategoria.financeiro, 'Abrir caixa'),
  fecharCaixa(PermissaoCategoria.financeiro, 'Fechar caixa'),
  realizarRetiradas(PermissaoCategoria.financeiro, 'Realizar retiradas de caixa'),
  realizarSuprimentos(PermissaoCategoria.financeiro, 'Realizar suprimentos de caixa'),
  consultarRelatorioCaixa(PermissaoCategoria.financeiro, 'Consultar relatório de caixa'),
  receberMensalidades(PermissaoCategoria.financeiro, 'Receber mensalidades'),
  historicoPagamentos(PermissaoCategoria.financeiro, 'Histórico de pagamentos'),
  emitirComprovantes(PermissaoCategoria.financeiro, 'Emitir comprovantes'),

  // Sistema
  relatorios(PermissaoCategoria.sistema, 'Relatórios'),
  configuracoes(PermissaoCategoria.sistema, 'Configurações da academia'),
  gerenciarFuncionarios(PermissaoCategoria.sistema, 'Gerenciar funcionários'),
  controleCatraca(PermissaoCategoria.sistema, 'Controle da catraca');

  const Permission(this.categoria, this.label);

  final PermissaoCategoria categoria;
  final String label;

  String get firestoreValue => name;

  static Permission? fromFirestoreValue(String? value) {
    for (final permission in Permission.values) {
      if (permission.firestoreValue == value) return permission;
    }
    return null;
  }

  /// Converte uma lista bruta vinda do Firestore (`List<dynamic>` de
  /// strings), ignorando silenciosamente valores desconhecidos/legados —
  /// mesma postura defensiva usada nos outros models do app.
  static Set<Permission> setFromFirestoreValues(List<dynamic>? values) {
    if (values == null) return const {};
    return values
        .map((value) => Permission.fromFirestoreValue(value as String?))
        .whereType<Permission>()
        .toSet();
  }
}
