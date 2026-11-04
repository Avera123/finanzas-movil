import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';
import 'support/fakes.dart';

void main() {
  late FakeAdapter adapter;
  late MemoryStore store;
  late BackendClient client;
  setUp(() {
    adapter = FakeAdapter();
    store = MemoryStore();
    client = BackendClient(
        dio: Dio()..httpClientAdapter = adapter,
        store: store,
        baseUrl: 'https://api.example.test',
        now: () => testNow);
  });
  tearDown(() => client.close());
  test('Login guarda solo cookie sesion y GET usa esa cookie', () async {
    adapter.headers = {
      'set-cookie': [
        'other=ignored; Path=/',
        '${testCookie()}; HttpOnly; Path=/; Secure'
      ]
    };
    await client.login('synthetic-test-input');
    expect(store.value, testCookie());
    expect(adapter.requests.single.path, '/api/login');
    adapter.body = stateFixture();
    final data = await client.readState();
    expect(data.netBalance, 800000);
    expect(adapter.requests.last.headers['Cookie'], testCookie());
    expect(adapter.requests.last.followRedirects, false);
    expect(adapter.requests.map((r) => '${r.method} ${r.path}'),
        ['POST /api/login', 'GET /api/state']);
  });
  test('401 y 429 no guardan sesión ni muestran respuesta sin filtrar',
      () async {
    for (final code in [401, 429]) {
      adapter.status = code;
      adapter.body = {'error': 'private server diagnostics'};
      await expectLater(
          client.login('synthetic-test-input'), throwsA(isA<ApiFailure>()));
      expect(store.value, isNull);
    }
  });
  test('Login rechaza respuesta sin cookie, expirada o malformada', () async {
    for (final raw in [
      '',
      'other=x',
      'sesion=bad',
      testCookie(expired: true)
    ]) {
      adapter.headers = {
        'set-cookie': [raw]
      };
      await expectLater(
          client.login('synthetic-test-input'), throwsA(isA<ApiFailure>()));
      expect(store.value, isNull);
    }
  });
  test('Login rechaza ok falso aunque tenga cookie', () async {
    adapter.headers = {
      'set-cookie': [testCookie()]
    };
    adapter.body = {'ok': false};
    await expectLater(
        client.login('synthetic-test-input'), throwsA(isA<ApiFailure>()));
    expect(store.value, isNull);
  });
  test('Almacenamiento fallido no produce login exitoso', () async {
    store.failWrite = true;
    adapter.headers = {
      'set-cookie': [testCookie()]
    };
    await expectLater(client.login('synthetic-test-input'), throwsStateError);
    expect(store.value, isNull);
  });
  test('Sesión persistida se restaura; expirada se borra sin red', () async {
    store.value = testCookie();
    expect(await client.hasSession(), true);
    store.value = testCookie(expired: true);
    expect(await client.hasSession(), false);
    expect(store.value, isNull);
    expect(adapter.requests, isEmpty);
  });
  test('401 al consultar elimina sesión y pide entrar', () async {
    store.value = testCookie();
    adapter.status = 401;
    await expectLater(
        client.readState(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.unauthorized, 'unauthorized', true)));
    expect(store.value, isNull);
  });
  test('Sin sesión no consulta datos', () async {
    await expectLater(client.readState(), throwsA(isA<ApiFailure>()));
    expect(adapter.requests, isEmpty);
  });
  test('Timeout y error 500 mantienen sesión para reintentar', () async {
    store.value = testCookie();
    adapter.failure = DioExceptionType.connectionTimeout;
    await expectLater(client.readState(), throwsA(isA<ApiFailure>()));
    expect(store.value, testCookie());
    adapter.failure = null;
    adapter.status = 500;
    await expectLater(client.readState(), throwsA(isA<ApiFailure>()));
    expect(store.value, testCookie());
  });
  test('Estado malformado se reporta como error', () async {
    store.value = testCookie();
    adapter.body = {'error': 'bad'};
    await expectLater(client.readState(), throwsA(isA<ApiFailure>()));
  });
  test('Logout offline borra sesión local', () async {
    store.value = testCookie();
    adapter.failure = DioExceptionType.connectionError;
    await client.logout();
    expect(store.value, isNull);
    expect(adapter.requests.single.path, '/api/logout');
  });
  test('URL insegura, credenciales y rutas se rechazan antes de red', () async {
    for (final url in [
      '',
      'http://api.example.test',
      'https://user:pass@api.example.test',
      'https://api.example.test/path',
      'https://api.example.test?x=y'
    ]) {
      final other = BackendClient(
          dio: Dio()..httpClientAdapter = adapter, store: store, baseUrl: url);
      await expectLater(
          other.login('synthetic-test-input'), throwsA(isA<ApiFailure>()));
      other.close();
    }
    expect(adapter.requests, isEmpty);
  });
  test('Redirecciones se rechazan sin guardar sesión', () async {
    adapter.status = 302;
    adapter.headers = {
      'location': ['https://other.example.test']
    };
    await expectLater(
        client.login('synthetic-test-input'), throwsA(isA<ApiFailure>()));
    expect(store.value, isNull);
    expect(adapter.requests.single.followRedirects, false);
  });
}
