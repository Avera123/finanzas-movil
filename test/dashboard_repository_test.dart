import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';
import 'package:finanzas_movil/src/features/dashboard/data/dashboard_repository.dart';
import 'support/fakes.dart';

void main() {
  test('Repositorio entrega perfil y documento de una sesión con versión',
      () async {
    final store = MemoryStore()..value = testCookie();
    final adapter = FakeAdapter();
    adapter.bodiesByPath['/api/me'] = profileFixture();
    adapter.bodiesByPath['/api/state'] = {...stateFixture(), 'version': 4};
    final client = BackendClient(
        dio: Dio()..httpClientAdapter = adapter,
        store: store,
        baseUrl: 'https://api.example.test',
        now: () => testNow);
    addTearDown(client.close);
    final snapshot = await DashboardRepository(client).load();
    expect(snapshot.profile.email, 'test@example.test');
    expect(snapshot.document.version, 4);
    expect(snapshot.finances.netBalance, 800000);
    expect(adapter.requests.map((r) => r.path), ['/api/me', '/api/state']);
  });

  test('Cambiar sesión mientras llega el perfil descarta la carga anterior',
      () async {
    final store = MemoryStore()..value = testCookie();
    final adapter = FakeAdapter();
    adapter.bodiesByPath['/api/me'] = profileFixture();
    adapter.bodiesByPath['/api/state'] = stateFixture();
    final started = Completer<void>(), release = Completer<void>();
    adapter.beforeResponse = (r) async {
      if (r.path == '/api/me') {
        started.complete();
        await release.future;
      }
    };
    final client = BackendClient(
        dio: Dio()..httpClientAdapter = adapter,
        store: store,
        baseUrl: 'https://api.example.test',
        now: () => testNow);
    addTearDown(client.close);
    final loading = DashboardRepository(client).load();
    await started.future;
    await client.logout();
    adapter.headers = {
      'set-cookie': [testCookie(userId: 'other-user')]
    };
    await client.login('other@example.test', 'synthetic-other-input');
    final expectation = expectLater(
        loading,
        throwsA(isA<ApiFailure>()
            .having((e) => e.message, 'message', contains('sesión cambió'))));
    release.complete();
    await expectation;
    expect(adapter.requests.where((r) => r.path == '/api/state'), isEmpty);
  });
}
