import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/app.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';
import 'support/fakes.dart';

void main() {
  late FakeAdapter adapter;
  late MemoryStore store;
  late BackendClient client;
  setUp(() {
    adapter = FakeAdapter();
    adapter.bodiesByPath['/api/me'] = profileFixture();
    store = MemoryStore();
    client = BackendClient(
        dio: Dio()..httpClientAdapter = adapter,
        store: store,
        baseUrl: 'https://api.example.test',
        now: () => testNow);
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      backendClientProvider.overrideWithValue(client),
    ], child: const FinanzasApp()));
    await tester.pumpAndSettle();
  }

  tearDown(() => client.close());
  testWidgets('App real muestra login y valida contraseña vacía',
      (tester) async {
    await mount(tester);
    expect(find.text('Finanzas Móvil'), findsOneWidget);
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });
  testWidgets(
      'Error de login permite reintentar sin mostrar diagnóstico privado',
      (tester) async {
    adapter.status = 429;
    adapter.body = {'error': 'private diagnostic'};
    await mount(tester);
    await tester.enterText(
        find.byKey(const ValueKey('email')), 'test@example.test');
    await tester.enterText(
        find.byKey(const ValueKey('password')), 'synthetic-test-input');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(
        find.text('Demasiados intentos. Espera 15 minutos.'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });
  testWidgets('Restaura sesión y muestra saldo real del fixture',
      (tester) async {
    store.value = testCookie();
    adapter.body = stateFixture();
    await mount(tester);
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text(r'$ 800000 COP'), findsOneWidget);
    expect(find.text('test@example.test'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
  });
  testWidgets('Sesión vencida en servidor ofrece volver a entrar',
      (tester) async {
    store.value = testCookie();
    adapter.status = 401;
    await mount(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
    expect(store.value, isNull);
  });
  testWidgets('Logout funciona aunque el servidor no responda', (tester) async {
    store.value = testCookie();
    adapter.body = stateFixture();
    await mount(tester);
    adapter.failure = DioExceptionType.connectionError;
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
    expect(store.value, isNull);
  });
  testWidgets('Login cabe con teclado en pantalla pequeña', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mount(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Valida contraseña vacía después del correo', (tester) async {
    await mount(tester);
    await tester.enterText(
        find.byKey(const ValueKey('email')), 'test@example.test');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('Login, logout y otra cuenta no reutilizan datos anteriores',
      (tester) async {
    adapter.headers = {
      'set-cookie': [testCookie()]
    };
    adapter.bodiesByPath['/api/state'] = stateFixture();
    await mount(tester);
    await tester.enterText(
        find.byKey(const ValueKey('email')), ' TEST@example.test ');
    await tester.enterText(
        find.byKey(const ValueKey('password')), 'synthetic-test-input');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('test@example.test'), findsOneWidget);
    expect(find.text(r'$ 800000 COP'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text(r'$ 800000 COP'), findsNothing);
    expect(store.value, isNull);
    adapter.headers = {
      'set-cookie': [testCookie(userId: 'other-user')]
    };
    adapter.bodiesByPath['/api/me'] =
        profileFixture(userId: 'other-user', email: 'other@example.test');
    adapter.bodiesByPath['/api/state'] = {'version': 1, 'acc': [], 'exp': []};
    await tester.enterText(
        find.byKey(const ValueKey('email')), 'other@example.test');
    await tester.enterText(
        find.byKey(const ValueKey('password')), 'synthetic-other-input');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('other@example.test'), findsOneWidget);
    expect(find.text('test@example.test'), findsNothing);
    expect(find.text(r'$ 0 COP'), findsOneWidget);
    expect(find.text(r'$ 800000 COP'), findsNothing);
  });

  testWidgets('Perfil revocado no consulta finanzas ni muestra saldos',
      (tester) async {
    store.value = testCookie();
    adapter.status = 401;
    await mount(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(adapter.requests.map((r) => r.path), ['/api/me']);
    expect(find.textContaining('COP'), findsNothing);
  });
}
