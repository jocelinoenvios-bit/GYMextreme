import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/utils/whatsapp.dart';

void main() {
  group('linkWhatsapp', () {
    test('numero brasileiro sem codigo do pais recebe o 55 na frente', () {
      expect(linkWhatsapp('11999998888'), 'https://wa.me/5511999998888');
    });

    test('numero que ja vem com o codigo do pais nao duplica', () {
      expect(linkWhatsapp('5511999998888'), 'https://wa.me/5511999998888');
    });

    test('remove pontuacao (parenteses, espaco, hifen) antes de montar o link', () {
      expect(linkWhatsapp('(11) 99999-8888'), 'https://wa.me/5511999998888');
    });
  });
}
