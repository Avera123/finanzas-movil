import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/user_profile.dart';
import 'package:finanzas_movil/src/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:finanzas_movil/src/features/dashboard/application/dashboard_controller.dart';
import 'package:finanzas_movil/src/features/plans/presentation/capital_screen.dart';
import 'support/fakes.dart';

void main() {
  for (final width in [320.0, 768.0]) {
    testWidgets('Savings and investment UI at $width and 200 percent text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fixture = jsonDecode(
              File('test/fixtures/capital_reference.json').readAsStringSync())
          as Map;
      final source = fixture['contributionCases'][0]['data'] as Map;
      final raw = <String, dynamic>{
        'version': 1,
        'exp': [],
        ...source,
        'investments': [
          {
            'id': 'i',
            'name': 'Synthetic investment',
            'mode': 'fixed',
            'value': 100,
            'rate': 0,
            'kind': 'Fondo',
            'months': 12,
            'startM': '2026-11'
          }
        ]
      };
      final snapshot = DashboardSnapshot(UserProfile.fromJson(profileFixture()),
          FinanceDocument.fromJson(raw));
      await tester.pumpWidget(ProviderScope(overrides: [
        financeStateProvider.overrideWith((ref) async => snapshot)
      ], child: const MaterialApp(home: CapitalScreen())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Fixture fund'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Inversiones'), -100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Inversiones'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Synthetic investment'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Crear inversión'), -100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Crear inversión'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva inversión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
