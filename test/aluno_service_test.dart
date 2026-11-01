import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/services/aluno_service.dart';

/// Testa `AlunoService.dadosCadastraisParaFirestore` — a função pura
/// que corrige o bug de "salvar a aba Dados apaga campos operacionais/
/// financeiros" (ver `test/dados_tab_test.dart` pro reprodutor no nível
/// de widget, e `functions/test/aluno-dados-cadastrais.emulator.js` pro
/// reprodutor no nível do Firestore de verdade). Aqui a garantia testada
/// é a mais forte possível: não importa o que o `Aluno` passado tenha
/// nos campos operacionais, o mapa devolvido nunca inclui essas chaves.
void main() {
  group('AlunoService.dadosCadastraisParaFirestore', () {
    const chavesOperacionais = [
      'ativo',
      'bloqueado',
      'proximoVencimento',
      'unidadeId',
      'dataInativacao',
      'dataReativacao',
      'reativadoPorUid',
      'reativadoPorNome',
      'whatsappOptIn',
    ];

    test('nunca inclui nenhum campo operacional/financeiro, mesmo quando o Aluno os tem preenchidos', () {
      final aluno = Aluno(
        uid: 'aluno-1',
        telefone: '11999998888',
        ativo: false,
        bloqueado: true,
        proximoVencimento: DateTime(2026, 12, 10),
        unidadeId: 'unidade-1',
        dataInativacao: DateTime(2026, 3, 1),
        dataReativacao: DateTime(2026, 5, 20),
        reativadoPorUid: 'staff-1',
        reativadoPorNome: 'Ana',
        whatsappOptIn: true,
      );

      final dados = AlunoService.dadosCadastraisParaFirestore(aluno);

      for (final chave in chavesOperacionais) {
        expect(
          dados.containsKey(chave),
          isFalse,
          reason: '"$chave" nunca deve aparecer no mapa de dados cadastrais',
        );
      }
    });

    test('nunca inclui campos operacionais mesmo quando o Aluno é só o construtor padrão (o caso real do bug)', () {
      // Este é exatamente o caso que causava o bug: DadosTab reconstrói
      // um Aluno só com os campos do formulário, deixando os
      // operacionais nos valores padrão do construtor (ativo: true,
      // bloqueado: false, os demais null) — antes da correção, esses
      // valores padrão eram gravados por cima do que já existia.
      const aluno = Aluno(uid: 'aluno-1', telefone: '11999998888');

      final dados = AlunoService.dadosCadastraisParaFirestore(aluno);

      for (final chave in chavesOperacionais) {
        expect(dados.containsKey(chave), isFalse);
      }
    });

    test('inclui os campos cadastrais esperados', () {
      final aluno = Aluno(
        uid: 'aluno-1',
        telefone: '11999998888',
        cpf: '12345678900',
        dataInicio: DateTime(2026, 1, 1),
        diaVencimento: 10,
      );

      final dados = AlunoService.dadosCadastraisParaFirestore(aluno);

      expect(dados['telefone'], '11999998888');
      expect(dados['cpf'], '12345678900');
      expect(dados['diaVencimento'], 10);
      expect(dados.containsKey('dataInicio'), isTrue);
      expect(dados.containsKey('endereco'), isTrue);
    });

    test('preserva cadastradoPorUid/Nome só quando presentes (não sobrescreve com null)', () {
      const semAuditoria = Aluno(uid: 'aluno-1');
      final dados = AlunoService.dadosCadastraisParaFirestore(semAuditoria);
      expect(dados.containsKey('cadastradoPorUid'), isFalse);
      expect(dados.containsKey('cadastradoPorNome'), isFalse);

      const comAuditoria = Aluno(
        uid: 'aluno-1',
        cadastradoPorUid: 'staff-1',
        cadastradoPorNome: 'Ana',
      );
      final dados2 = AlunoService.dadosCadastraisParaFirestore(comAuditoria);
      expect(dados2['cadastradoPorUid'], 'staff-1');
      expect(dados2['cadastradoPorNome'], 'Ana');
    });
  });
}
