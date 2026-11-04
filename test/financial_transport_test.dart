import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';
import 'package:finanzas_movil/src/core/api/financial_save.dart';
import 'support/fakes.dart';

void main() {
  late FakeAdapter adapter;
  late BackendClient client;
  late MemoryStore store;
  setUp(() {
    adapter = FakeAdapter();
    store = MemoryStore()..value = testCookie();
    client = BackendClient(
        dio: Dio()..httpClientAdapter = adapter,
        store: store,
        baseUrl: 'https://api.example.test',
        now: () => testNow);
  });
  tearDown(() => client.close());
  test('PUT sends complete versioned payload to verified endpoint', () async {
    adapter.body = {'version': 2};
    final payload = stateFixture()..['unknown'] = {'future': true};
    expect(await client.putDocument(payload, client.sessionGeneration), 2);
    expect(adapter.requests.single.path, '/api/state');
    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.data, payload);
  });
  for (final pair in {
    409: SaveStatus.conflict,
    400: SaveStatus.rejected,
    403: SaveStatus.rejected,
    500: SaveStatus.uncertain,
    401: SaveStatus.sessionChanged
  }.entries) {
    test('HTTP ${pair.key} is classified safely', () async {
      adapter.status = pair.key;
      await expectLater(
          client.putDocument(stateFixture(), client.sessionGeneration),
          throwsA(isA<SaveFailure>()
              .having((e) => e.status, 'status', pair.value)));
      if (pair.key == 401) expect(store.value, isNull);
    });
  }
  test('Timeout and malformed success are uncertain', () async {
    adapter.failure = DioExceptionType.receiveTimeout;
    await expectLater(
        client.putDocument(stateFixture(), client.sessionGeneration),
        throwsA(isA<SaveFailure>()
            .having((e) => e.status, 'status', SaveStatus.uncertain)));
    adapter.failure = null;
    adapter.body = {'ok': true};
    await expectLater(
        client.putDocument(stateFixture(), client.sessionGeneration),
        throwsA(isA<SaveFailure>()
            .having((e) => e.status, 'status', SaveStatus.uncertain)));
  });
  test('Old session cannot issue a write', () async {
    await expectLater(
        client.putDocument(stateFixture(), -1),
        throwsA(isA<SaveFailure>()
            .having((e) => e.status, 'status', SaveStatus.sessionChanged)));
    expect(adapter.requests, isEmpty);
  });
}
