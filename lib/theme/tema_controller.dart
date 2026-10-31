import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Guarda qual tema está ativo e avisa quem escuta quando ele muda.
///
/// Como as cores do app são lidas de [AppColors] (que aponta pra paleta
/// ativa) e não do `Theme.of(context)`, trocar de tema exige duas coisas
/// na ordem certa: apontar [AppColors.paleta] pra paleta nova e só então
/// reconstruir a árvore. É o que [trocar] faz.
///
/// A escolha fica salva no próprio aparelho, não no cadastro: é
/// preferência de quem está usando o celular, não do aluno/funcionário.
class TemaController extends ChangeNotifier {
  TemaController({TemaApp inicial = TemaApp.escuro}) : _tema = inicial {
    AppColors.paleta = PaletaApp.de(_tema);
  }

  static const _chave = 'tema_app';

  TemaApp _tema;
  TemaApp get tema => _tema;

  /// Lê a preferência salva. Se nunca foi escolhida (ou se a leitura
  /// falhar — o app não deve deixar de abrir por causa disso), fica no
  /// escuro, que é como o app sempre foi.
  static Future<TemaApp> carregarPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_chave) == TemaApp.claro.name
          ? TemaApp.claro
          : TemaApp.escuro;
    } catch (_) {
      return TemaApp.escuro;
    }
  }

  Future<void> trocar(TemaApp novo) async {
    if (novo == _tema) return;
    _tema = novo;
    AppColors.paleta = PaletaApp.de(novo);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, novo.name);
    } catch (_) {
      // Não conseguiu salvar: o tema já trocou na tela, só não vai
      // sobreviver ao fechar o app. Melhor isso do que quebrar a troca.
    }
  }
}

/// Dá acesso ao [TemaController] de qualquer tela — hoje só a engrenagem
/// de configurações precisa, pra oferecer a troca de tema. Mora aqui, e
/// não junto do `GymExtremeApp` que o instala, pra as telas poderem
/// alcançá-lo sem importar o app inteiro de volta.
class TemaEscopo extends InheritedNotifier<TemaController> {
  const TemaEscopo({
    super.key,
    required TemaController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Devolve `null` fora de um [TemaEscopo] — é o caso dos testes de
  /// widget, que montam uma tela solta sem o app em volta. Quem usa deve
  /// simplesmente esconder a opção de tema nesse caso.
  static TemaController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TemaEscopo>()?.notifier;
}
