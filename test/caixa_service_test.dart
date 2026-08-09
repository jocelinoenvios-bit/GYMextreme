import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/caixa_movimentacao.dart';
import 'package:gymextreme_app/services/caixa_service.dart';

import 'support/fake_caixa_service.dart';

void main() {
  group('abrirCaixa', () {
    test('abre um caixa novo com o valor inicial informado', () async {
      final service = FakeCaixaService();

      final id = await service.abrirCaixa(
        valorInicial: 100,
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );

      expect(id, isNotEmpty);
      expect(service.caixaAberto, isNotNull);
      expect(service.caixaAberto!.valorInicial, 100);
      expect(service.caixaAberto!.status, StatusCaixa.aberto);
      expect(service.caixaAberto!.abertoPorNome, 'Recepção Ana');
    });

    test('bloqueia abrir um segundo caixa enquanto o primeiro estiver aberto', () async {
      final service = FakeCaixaService();
      await service.abrirCaixa(valorInicial: 100, staffUid: 'staff1', staffNome: 'Ana');

      expect(
        () => service.abrirCaixa(valorInicial: 50, staffUid: 'staff2', staffNome: 'Bia'),
        throwsA(isA<CaixaServiceException>()),
      );
    });
  });

  group('registrarMovimentacao', () {
    test('suprimento soma ao saldo (valor sempre positivo)', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      await service.registrarMovimentacao(
        id,
        tipo: TipoMovimentacaoCaixa.suprimento,
        valor: 50,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.movimentacoes.single.valor, 50);
    });

    test('retirada subtrai do saldo (guardada com valor negativo)', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      await service.registrarMovimentacao(
        id,
        tipo: TipoMovimentacaoCaixa.retirada,
        valor: 30,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.movimentacoes.single.valor, -30);
    });

    test('ajuste aceita valor negativo diretamente (ja vem assinado)', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      await service.registrarMovimentacao(
        id,
        tipo: TipoMovimentacaoCaixa.ajuste,
        valor: -5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.movimentacoes.single.valor, -5);
    });

    test('recebimento avulso e rejeitado — deve usar registrarRecebimentoContaReceber', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      expect(
        () => service.registrarMovimentacao(
          id,
          tipo: TipoMovimentacaoCaixa.recebimento,
          valor: 50,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<CaixaServiceException>()),
      );
    });

    test('nao registra movimentacao num caixa que nao esta aberto', () async {
      final service = FakeCaixaService();

      expect(
        () => service.registrarMovimentacao(
          'caixa-inexistente',
          tipo: TipoMovimentacaoCaixa.suprimento,
          valor: 10,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<CaixaServiceException>()),
      );
    });
  });

  group('registrarRecebimentoContaReceber', () {
    test('registra a movimentacao do tipo recebimento com a referencia da conta', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      final movId = await service.registrarRecebimentoContaReceber(
        caixaId: id,
        alunoUid: 'aluno1',
        contaReceberId: 'conta1',
        valorPago: 129.9,
        desconto: 0,
        jurosMulta: 0,
        dataPagamento: DateTime(2026, 8, 10),
        formaPagamento: 'PIX',
        staffUid: 's1',
        staffNome: 'Ana',
      );

      final mov = service.movimentacoes.single;
      expect(mov.id, movId);
      expect(mov.tipo, TipoMovimentacaoCaixa.recebimento);
      expect(mov.valor, 129.9);
      expect(mov.contaReceberAlunoId, 'aluno1');
      expect(mov.contaReceberId, 'conta1');
      expect(
        service.ultimoRecebimentoViaCaixa,
        (caixaId: id, alunoUid: 'aluno1', contaReceberId: 'conta1', valorPago: 129.9),
      );
    });

    test('recusa registrar de novo a mesma cobranca (duplicidade)', () async {
      final service = FakeCaixaService()..lancarErroAoRegistrarRecebimento = true;
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      expect(
        () => service.registrarRecebimentoContaReceber(
          caixaId: id,
          alunoUid: 'aluno1',
          contaReceberId: 'conta1',
          valorPago: 129.9,
          desconto: 0,
          jurosMulta: 0,
          dataPagamento: DateTime(2026, 8, 10),
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<CaixaServiceException>()),
      );
    });

    test('recusa registrar num caixa que nao esta mais aberto', () async {
      final service = FakeCaixaService();

      expect(
        () => service.registrarRecebimentoContaReceber(
          caixaId: 'caixa-fechado',
          alunoUid: 'aluno1',
          contaReceberId: 'conta1',
          valorPago: 129.9,
          desconto: 0,
          jurosMulta: 0,
          dataPagamento: DateTime(2026, 8, 10),
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<CaixaServiceException>()),
      );
    });
  });

  group('fecharCaixa', () {
    test('calcula o saldo esperado como valor inicial + soma das movimentacoes', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');
      await service.registrarMovimentacao(
        id,
        tipo: TipoMovimentacaoCaixa.suprimento,
        valor: 50,
        staffUid: 's1',
        staffNome: 'Ana',
      );
      await service.registrarMovimentacao(
        id,
        tipo: TipoMovimentacaoCaixa.retirada,
        valor: 20,
        staffUid: 's1',
        staffNome: 'Ana',
      );
      // Esperado: 100 + 50 - 20 = 130.

      await service.fecharCaixa(
        id,
        valorContado: 130,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      final fechado = service.historico.single;
      expect(fechado.status, StatusCaixa.fechado);
      expect(fechado.valorEsperadoNoFechamento, 130);
      expect(fechado.valorContado, 130);
      expect(fechado.diferenca, 0);
      expect(service.caixaAberto, isNull);
    });

    test('diferenca negativa quando o valor contado e menor que o esperado (falta)', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      await service.fecharCaixa(id, valorContado: 80, staffUid: 's1', staffNome: 'Ana');

      expect(service.historico.single.diferenca, -20);
    });

    test('diferenca positiva quando o valor contado e maior que o esperado (sobra)', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');

      await service.fecharCaixa(id, valorContado: 110, staffUid: 's1', staffNome: 'Ana');

      expect(service.historico.single.diferenca, 10);
    });

    test('nao fecha um caixa que ja esta fechado', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');
      await service.fecharCaixa(id, valorContado: 100, staffUid: 's1', staffNome: 'Ana');

      expect(
        () => service.fecharCaixa(id, valorContado: 100, staffUid: 's1', staffNome: 'Ana'),
        throwsA(isA<CaixaServiceException>()),
      );
    });

    test('depois de fechado, um novo caixa pode ser aberto normalmente', () async {
      final service = FakeCaixaService();
      final id = await service.abrirCaixa(valorInicial: 100, staffUid: 's1', staffNome: 'Ana');
      await service.fecharCaixa(id, valorContado: 100, staffUid: 's1', staffNome: 'Ana');

      final novoId = await service.abrirCaixa(valorInicial: 50, staffUid: 's1', staffNome: 'Ana');

      expect(novoId, isNotEmpty);
      expect(service.caixaAberto!.valorInicial, 50);
      expect(service.historico, hasLength(1));
    });
  });
}
