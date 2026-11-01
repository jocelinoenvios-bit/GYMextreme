import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `find.text`/`find.textContaining` só enxergam widgets `Text` (ou
/// `EditableText`) — várias telas desta área (linhas "Rótulo: valor")
/// montam o texto direto num `RichText` com múltiplos `TextSpan`, que o
/// finder padrão nunca encontra. Este finder varre o texto plano
/// (`toPlainText()`) de qualquer `RichText` da árvore.
Finder findRichTextContaining(String substring) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(substring),
  );
}
