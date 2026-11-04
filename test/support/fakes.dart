import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';

class MemoryStore implements SessionStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (failWrite) throw StateError('Storage unavailable');
    value = v;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body = <String, dynamic>{'ok': true};
  Map<String, List<String>> headers = {};
  DioExceptionType? failure;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

final testNow = DateTime.utc(2026, 11, 3);
// Synthetic fixture only, not a valid signed credential.
String testCookie({bool expired = false}) =>
    'sesion=${testNow.add(Duration(days: expired ? -1 : 1)).millisecondsSinceEpoch}.${List.filled(64, 'a').join()}';
Map<String, dynamic> stateFixture() => {
      'acc': [
        {'id': 'a', 'name': 'Test savings', 'type': 'Ahorros', 'bal': 1000000},
        {'id': 'b', 'name': 'Test credit', 'type': 'Crédito', 'bal': 200000},
      ],
      'exp': <Object>[],
    };
