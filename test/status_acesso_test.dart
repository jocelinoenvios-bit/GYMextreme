import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/constants/mensalidade.dart';
import 'package:gymextreme_app/utils/status_acesso.dart';

void main() {
  final vencimento = DateTime(2026, 8, 10);

  group('calcularStatusAcesso', () {
    test('sem vencimento configurado libera acesso (nao bloqueia por falta de dados)', () {
      final status = calcularStatusAcesso(proximoVencimento: null);
      expect(status.status, StatusMensalidade.semRegistro);
      expect(status.podeAcessar, isTrue);
    });

    test('hoje antes do vencimento fica em dia', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 3),
      );
      expect(status.status, StatusMensalidade.emDia);
      expect(status.podeAcessar, isTrue);
      expect(status.diasParaVencimento, 7);
    });

    test('regra atual (tolerancia zero): no dia seguinte ao vencimento ja bloqueia', () {
      expect(toleranciaMensalidadeDias, 0);
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 11, 6),
      );
      expect(status.status, StatusMensalidade.bloqueado);
      expect(status.podeAcessar, isFalse);
      expect(status.diasAtraso, 1);
    });

    test('exatamente no dia do vencimento ainda fica em dia', () {
      final status = calcularStatusAcesso(proximoVencimento: vencimento, hoje: vencimento);
      expect(status.status, StatusMensalidade.emDia);
      expect(status.diasParaVencimento, 0);
    });

    test('tolerancia de 7 dias (parametro): 1o dia de atraso, restam 7', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        toleranciaDias: 7,
        hoje: DateTime(2026, 8, 11),
      );
      expect(status.status, StatusMensalidade.tolerancia);
      expect(status.podeAcessar, isTrue);
      expect(status.diasAtraso, 1);
      expect(status.diasToleranciaRestantes, 7);
    });

    test('tolerancia de 7 dias (parametro): 2o dia de atraso, restam 6', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        toleranciaDias: 7,
        hoje: DateTime(2026, 8, 12),
      );
      expect(status.diasAtraso, 2);
      expect(status.diasToleranciaRestantes, 6);
    });

    test('tolerancia de 7 dias (parametro): 7o dia ainda libera', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        toleranciaDias: 7,
        hoje: DateTime(2026, 8, 17),
      );
      expect(status.status, StatusMensalidade.tolerancia);
      expect(status.podeAcessar, isTrue);
      expect(status.diasAtraso, 7);
      expect(status.diasToleranciaRestantes, 1);
    });

    test('tolerancia de 7 dias (parametro): 8o dia bloqueia', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        toleranciaDias: 7,
        hoje: DateTime(2026, 8, 18),
      );
      expect(status.status, StatusMensalidade.bloqueado);
      expect(status.podeAcessar, isFalse);
      expect(status.diasAtraso, 8);
    });

    test('continua bloqueado bem depois do fim da tolerancia', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 9, 10),
      );
      expect(status.status, StatusMensalidade.bloqueado);
      expect(status.podeAcessar, isFalse);
    });

    test('tolerancia customizada (ex.: 3 dias) respeita o parametro', () {
      final noLimite = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 13),
        toleranciaDias: 3,
      );
      expect(noLimite.status, StatusMensalidade.tolerancia);

      final depoisDoLimite = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 14),
        toleranciaDias: 3,
      );
      expect(depoisDoLimite.status, StatusMensalidade.bloqueado);
    });
  });

  group('mensagemNotificacaoMensalidade', () {
    test('7 dias antes do vencimento', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 3),
      );
      expect(
        mensagemNotificacaoMensalidade(status),
        'Atenção! Sua mensalidade vence em 7 dias.',
      );
    });

    test('3 dias antes do vencimento', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 7),
      );
      expect(mensagemNotificacaoMensalidade(status), 'Sua mensalidade está próxima do vencimento.');
    });

    test('no dia do vencimento', () {
      final status = calcularStatusAcesso(proximoVencimento: vencimento, hoje: vencimento);
      expect(mensagemNotificacaoMensalidade(status), 'Sua mensalidade vence hoje.');
    });

    test('dia comum antes do vencimento nao gera notificacao', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 5),
      );
      expect(mensagemNotificacaoMensalidade(status), isNull);
    });

    test('primeiro dia bloqueado (dia seguinte ao vencimento) avisa da suspensao', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 11),
      );
      expect(
        mensagemNotificacaoMensalidade(status),
        'Sua mensalidade permanece em atraso. Seu acesso ao aplicativo e '
        'à academia foi bloqueado até a regularização do pagamento.',
      );
    });

    test('dias seguintes bloqueado nao repetem a notificacao', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 25),
      );
      expect(mensagemNotificacaoMensalidade(status), isNull);
    });

    test('sem registro nao gera notificacao', () {
      final status = calcularStatusAcesso(proximoVencimento: null);
      expect(mensagemNotificacaoMensalidade(status), isNull);
    });
  });
}
