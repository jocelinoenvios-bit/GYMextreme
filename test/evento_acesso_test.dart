import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/evento_acesso.dart';

/// Testa `EventoAcesso` — model de leitura da coleção `eventosAcesso`
/// (acesso físico, gravado só pela Cloud Function do pipeline do
/// Control iDFace). `motivoLabel` espelha
/// `functions/lib/access/mensagens.js` (`mensagemParaMotivo`) — os
/// testes abaixo confirmam que cada motivo real bate com o texto
/// esperado, mesma ideia de `status_acesso_test.dart` espelhando
/// `status-acesso.js`.
void main() {
  group('EventoAcesso.fromFirestore', () {
    test('autorizado (resultado ALLOW) -> autorizado == true', () {
      final evento = EventoAcesso.fromFirestore('evt-1', {
        'resultado': 'ALLOW',
        'alunoUid': 'aluno-1',
      });
      expect(evento.resultado, ResultadoAcesso.autorizado);
      expect(evento.autorizado, isTrue);
    });

    test('negado (resultado DENY) -> autorizado == false', () {
      final evento = EventoAcesso.fromFirestore('evt-2', {
        'resultado': 'DENY',
        'motivo': 'STUDENT_BLOCKED',
      });
      expect(evento.resultado, ResultadoAcesso.negado);
      expect(evento.autorizado, isFalse);
    });

    test('resultado ausente/inesperado nunca é tratado como autorizado (fail-safe)', () {
      final evento = EventoAcesso.fromFirestore('evt-3', {});
      expect(evento.autorizado, isFalse);
    });

    test('aceita Timestamp do Firestore em criadoEm', () {
      final data = DateTime(2026, 3, 10, 8, 30);
      final evento = EventoAcesso.fromFirestore('evt-4', {
        'resultado': 'ALLOW',
        'criadoEm': Timestamp.fromDate(data),
      });
      expect(evento.criadoEm, data);
    });

    test('todos os campos são preservados', () {
      final evento = EventoAcesso.fromFirestore('evt-5', {
        'deviceId': 'device-1',
        'unidadeId': 'unidade-1',
        'alunoUid': 'aluno-1',
        'userIdDispositivo': '2001',
        'userName': 'Ana',
        'metodo': 'FACE',
        'resultado': 'DENY',
        'motivo': 'PAYMENT_OVERDUE',
        'confidence': 92.5,
        'portalId': '1',
        'tempoProcessamentoMs': 120,
        'erro': null,
      });
      expect(evento.deviceId, 'device-1');
      expect(evento.unidadeId, 'unidade-1');
      expect(evento.alunoUid, 'aluno-1');
      expect(evento.userIdDispositivo, '2001');
      expect(evento.userName, 'Ana');
      expect(evento.metodo, 'FACE');
      expect(evento.motivo, 'PAYMENT_OVERDUE');
      expect(evento.confidence, 92.5);
      expect(evento.portalId, '1');
      expect(evento.tempoProcessamentoMs, 120);
    });
  });

  group('EventoAcesso.motivoLabel — espelha functions/lib/access/mensagens.js', () {
    const casos = {
      'STUDENT_NOT_FOUND': 'Cadastro não encontrado',
      'INVALID_CREDENTIAL': 'Cadastro não encontrado',
      'STUDENT_INACTIVE': 'Matrícula inativa',
      'STUDENT_BLOCKED': 'Acesso bloqueado',
      'PLAN_EXPIRED': 'Plano expirado',
      'PAYMENT_OVERDUE': 'Mensalidade em atraso',
      'OUTSIDE_ALLOWED_HOURS': 'Fora do horário permitido',
      'UNIT_NOT_ALLOWED': 'Acesso não permitido nesta unidade',
      'DEVICE_NOT_AUTHORIZED': 'Dispositivo não autorizado',
      'RATE_LIMITED': 'Chamadas rápidas demais do dispositivo',
      'SYSTEM_ERROR': 'Erro no sistema',
    };

    for (final entry in casos.entries) {
      test('motivo ${entry.key} -> "${entry.value}"', () {
        final evento = EventoAcesso.fromFirestore('evt', {
          'resultado': 'DENY',
          'motivo': entry.key,
        });
        expect(evento.motivoLabel, entry.value);
      });
    }

    test('sem motivo (negado) cai no texto genérico "Acesso negado"', () {
      final evento = EventoAcesso.fromFirestore('evt', {'resultado': 'DENY'});
      expect(evento.motivoLabel, 'Acesso negado');
    });

    test('autorizado sem motivo mostra "Acesso liberado"', () {
      final evento = EventoAcesso.fromFirestore('evt', {'resultado': 'ALLOW'});
      expect(evento.motivoLabel, 'Acesso liberado');
    });
  });
}
