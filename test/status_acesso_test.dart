import 'package:flutter_test/flutter_test.dart';
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

    test('exatamente no dia do vencimento ainda fica em dia', () {
      final status = calcularStatusAcesso(proximoVencimento: vencimento, hoje: vencimento);
      expect(status.status, StatusMensalidade.emDia);
      expect(status.diasParaVencimento, 0);
    });

    test('1o dia de atraso entra em tolerancia com 7 dias restantes', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 11),
      );
      expect(status.status, StatusMensalidade.tolerancia);
      expect(status.podeAcessar, isTrue);
      expect(status.diasAtraso, 1);
      expect(status.diasToleranciaRestantes, 7);
    });

    test('2o dia de atraso restam 6 dias de tolerancia', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 12),
      );
      expect(status.diasAtraso, 2);
      expect(status.diasToleranciaRestantes, 6);
    });

    test('7o dia de atraso e o ultimo dia de tolerancia, ainda libera acesso', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 17),
      );
      expect(status.status, StatusMensalidade.tolerancia);
      expect(status.podeAcessar, isTrue);
      expect(status.diasAtraso, 7);
      expect(status.diasToleranciaRestantes, 1);
    });

    test('8o dia de atraso bloqueia o acesso', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
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

    test('1o dia de atraso avisa sobre a tolerancia', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 11),
      );
      expect(
        mensagemNotificacaoMensalidade(status),
        'Sua mensalidade está vencida. Você possui 7 dias de tolerância '
        'para continuar utilizando normalmente a academia.',
      );
    });

    test('dia do meio da tolerancia informa quantos dias restam', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 14),
      );
      expect(mensagemNotificacaoMensalidade(status), 'Restam 4 dias de tolerância.');
    });

    test('ultimo dia de tolerancia tem mensagem propria', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 17),
      );
      expect(
        mensagemNotificacaoMensalidade(status),
        'Hoje é o último dia de tolerância. Regularize sua mensalidade '
        'para evitar o bloqueio.',
      );
    });

    test('primeiro dia bloqueado avisa da suspensao', () {
      final status = calcularStatusAcesso(
        proximoVencimento: vencimento,
        hoje: DateTime(2026, 8, 18),
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
