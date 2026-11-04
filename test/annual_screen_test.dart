import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/user_profile.dart';
import 'package:finanzas_movil/src/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:finanzas_movil/src/features/dashboard/application/dashboard_controller.dart';
import 'package:finanzas_movil/src/features/dashboard/annual_screen.dart';
import 'support/fakes.dart';

void main() {
  for (final width in [320.0, 768.0]) {
    testWidgets('Annual table and month details at $width and 200 percent text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fixture = jsonDecode(
              File('test/fixtures/annual_reference.json').readAsStringSync())
          as Map;
      final snapshot = DashboardSnapshot(UserProfile.fromJson(profileFixture()),
          FinanceDocument.fromJson(fixture['data']));
      await tester.pumpWidget(ProviderScope(overrides: [
        financeStateProvider.overrideWith((ref) async => snapshot)
      ], child: MaterialApp(home: AnnualScreen(today: DateTime(2026, 11, 4)))));
      await tester.pumpAndSettle();
      expect(find.text('Resumen anual'), findsOneWidget);
      final chip = find.widgetWithText(ChoiceChip, '2026-11 · actual');
      await tester.scrollUntilVisible(chip.hitTestable(), 100,
          maxScrolls: 40, scrollable: find.byType(Scrollable).first);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Detalle de 2026-11'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(DataTable), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Total flujos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
