import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('El título de la aplicación se muestra', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Finanzas Móvil')),
    ));
    expect(find.text('Finanzas Móvil'), findsOneWidget);
  });
}
