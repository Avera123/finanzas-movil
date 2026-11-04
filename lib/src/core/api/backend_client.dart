import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const backendUrl = String.fromEnvironment('API_BASE_URL');

final backendClientProvider = Provider<BackendClient>((ref) => BackendClient());

class BackendClient {
  BackendClient({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: backendUrl)),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _cookieKey = 'backend_session_cookie';

  Future<void> login(String password) async {
    if (backendUrl.isEmpty) {
      throw StateError('Configura API_BASE_URL al ejecutar Flutter');
    }
    final response = await _dio.post<Object?>('/api/login', data: {'password': password});
    final rawCookie = response.headers.value('set-cookie');
    final cookie = rawCookie?.split(';').first;
    if (cookie == null || !cookie.startsWith('sesion=')) {
      throw StateError('El servidor no devolvió una sesión válida');
    }
    await _storage.write(key: _cookieKey, value: cookie);
  }

  Future<Map<String, dynamic>> readState() async {
    final cookie = await _storage.read(key: _cookieKey);
    if (cookie == null) throw StateError('Inicia sesión para continuar');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/state', options: Options(headers: {'Cookie': cookie}),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _storage.delete(key: _cookieKey);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final cookie = await _storage.read(key: _cookieKey);
    try {
      if (cookie != null) {
        await _dio.post<Object?>('/api/logout', options: Options(headers: {'Cookie': cookie}));
      }
    } finally {
      await _storage.delete(key: _cookieKey);
    }
  }
}
