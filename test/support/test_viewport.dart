import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Alguns formulários (cadastro, anamnese, termo, avaliação física) são
/// mais altos que a janela padrão de teste (800x600 lógicos) — sem isso,
/// o `ListView`/`Stepper` só monta na árvore de elementos os widgets
/// dentro da área visível (mais um pequeno cache extent), então
/// `find`/`tap`/`enterText` em qualquer coisa "abaixo da dobra" falha
/// com "0 widgets encontrados", mesmo que exista na lista lógica.
/// Aumenta a janela de teste pra caber o formulário inteiro de uma vez.
void usarViewportGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
