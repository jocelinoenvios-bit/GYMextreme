import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/widgets/gymextreme_logo.dart';

void main() {
  testWidgets('GymExtremeLogo mostra o nome da marca', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: GymExtremeLogo()),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/logo_leao.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == 'GYM XTREME',
      ),
      findsOneWidget,
    );
  });
}
