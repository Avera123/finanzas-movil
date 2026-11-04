import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/user_profile.dart';
import 'package:finanzas_movil/src/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:finanzas_movil/src/features/dashboard/application/dashboard_controller.dart';
import 'package:finanzas_movil/src/features/plans/presentation/plans_screen.dart';
import 'support/fakes.dart';

void main() {
  for (final width in [320.0, 768.0]) {
    testWidgets('Debt and receivable screens at $width with large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final raw = stateFixture()
        ..addAll({
          'debts': [
            {
              'id': 'd',
              'name': 'Synthetic debt',
              'mode': 'fixed',
              'total': 1000,
              'cuota': 100,
              'rate': 0,
              'startM': '2026-11'
            }
          ],
          'loans': [
            {
              'id': 'l',
              'person': 'Synthetic borrower',
              'total': 500,
              'lentOn': '2026-11-01',
              'dueOn': '2027-01-01'
            }
          ],
        });
      final snapshot = DashboardSnapshot(UserProfile.fromJson(profileFixture()),
          FinanceDocument.fromJson(raw));
      await tester.pumpWidget(ProviderScope(overrides: [
        financeStateProvider.overrideWith((ref) async => snapshot)
      ], child: const MaterialApp(home: PlansScreen())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Synthetic debt'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Dinero que me deben'), -100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Dinero que me deben'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Synthetic borrower'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }
}
