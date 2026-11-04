import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/features/movements/presentation/operation_screen.dart';
import 'support/fakes.dart';

void main() {
  late FakeAdapter adapter;
  late BackendClient client;
  late FinanceDocument doc;
  setUp(() {
    adapter = FakeAdapter();
    final data = stateFixture();
    data['exp'] = [
      {
        'id': 'e',
        'name': 'Fixture expense',
        'm': '2026-11',
        'cat': 'Vida',
        'amt': 100,
        'acc': 'a',
        'paid': false
      }
    ];
    doc = FinanceDocument.fromJson(data);
    adapter.body = {...data, 'version': 2};
    client = BackendClient(
        dio: Dio()..httpClientAdapter = adapter,
        store: MemoryStore()..value = testCookie(),
        baseUrl: 'https://api.example.test',
        now: () => testNow);
  });
  tearDown(() => client.close());
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [backendClientProvider.overrideWithValue(client)],
        child: MaterialApp(
            home: OperationScreen(
                document: doc,
                title: 'Pagar fixture',
                prepare: (c) => c.togglePayment('e')))));
    await tester.pumpAndSettle();
  }

  testWidgets('Preview and cancel do not write financial state',
      (tester) async {
    await mount(tester);
    expect(find.textContaining('999.900'), findsOneWidget);
    expect(adapter.requests, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(adapter.requests, isEmpty);
    expect(doc.summary.accounts.first.balance, 1000000);
  });
  testWidgets('Confirmation sends once then reloads', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'PUT').length, 1);
    expect(find.text('Cambio guardado y datos actualizados.'), findsOneWidget);
    expect(find.text('Confirmar y guardar'), findsNothing);
  });
  testWidgets('Conflict is visible and no retry button remains',
      (tester) async {
    adapter.status = 409;
    await mount(tester);
    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Los datos cambiaron'), findsOneWidget);
    expect(find.text('Confirmar y guardar'), findsNothing);
    expect(adapter.requests.length, 1);
  });
}
