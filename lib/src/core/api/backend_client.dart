import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/finance_state.dart';

const backendUrl = String.fromEnvironment('API_BASE_URL');
final backendClientProvider = Provider<BackendClient>((ref) {
  final client = BackendClient();
  ref.onDispose(client.close);
  return client;
});

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.unauthorized = false});
  final String message;
  final bool unauthorized;
  @override
  String toString() => message;
}

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({required String origin, FlutterSecureStorage? storage})
      : _key = 'session_v2_${base64Url.encode(utf8.encode(origin))}',
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.unlocked_this_device),
            );
  final FlutterSecureStorage _storage;
  final String _key;
  @override
  Future<String?> read() async {
    // The scaffold used a global key. Never reuse it with another API origin.
    await _storage.delete(key: 'backend_session_cookie');
    return _storage.read(key: _key);
  }

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: 'backend_session_cookie');
  }
}

class BackendClient {
  BackendClient(
      {Dio? dio,
      SessionStore? store,
      String baseUrl = backendUrl,
      DateTime Function()? now})
      : _dio = dio ?? Dio(),
        _store = store ?? SecureSessionStore(origin: baseUrl),
        _baseUrl = baseUrl,
        _now = now ?? DateTime.now {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    );
  }
  final Dio _dio;
  final SessionStore _store;
  final String _baseUrl;
  final DateTime Function() _now;
  void _checkUrl() {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiFailure(
          'Configura API_BASE_URL con el origen HTTPS de tu API.');
    }
  }

  bool _validCookie(String value) {
    // Contract verified in server/app.js: milliseconds expiry and SHA-256 HMAC.
    final match = RegExp(r'^sesion=(\d+)\.([a-f0-9]{64})$').firstMatch(value);
    final expiry = match == null ? null : int.tryParse(match.group(1)!);
    return expiry != null && expiry > _now().millisecondsSinceEpoch;
  }

  Future<bool> hasSession() async {
    final cookie = await _store.read();
    if (cookie == null) return false;
    if (_validCookie(cookie)) return true;
    await _store.clear();
    return false;
  }

  Future<void> login(String password) async {
    _checkUrl();
    if (password.trim().isEmpty) {
      throw const ApiFailure('Escribe tu contraseña.');
    }
    await _store.clear();
    try {
      final response =
          await _dio.post<Object?>('/api/login', data: {'password': password});
      if (response.data is! Map || (response.data as Map)['ok'] != true) {
        throw const ApiFailure('Respuesta de inicio de sesión inválida.');
      }
      String? session;
      for (final raw in response.headers['set-cookie'] ?? <String>[]) {
        final cookie = Cookie.fromSetCookieValue(raw);
        if (cookie.name == 'sesion') session = '${cookie.name}=${cookie.value}';
      }
      if (session == null || !_validCookie(session)) {
        throw const ApiFailure('El servidor no devolvió una sesión válida.');
      }
      await _store.write(session);
    } on DioException catch (e) {
      throw _failure(e);
    } on FormatException {
      throw const ApiFailure('El servidor no devolvió una sesión válida.');
    } on HttpException {
      throw const ApiFailure('El servidor no devolvió una sesión válida.');
    }
  }

  Future<FinanceState> readState() async {
    _checkUrl();
    if (!await hasSession()) {
      throw const ApiFailure('Inicia sesión para continuar.',
          unauthorized: true);
    }
    final cookie = await _store.read();
    try {
      final response = await _dio.get<Object?>('/api/state',
          options: Options(headers: {'Cookie': cookie}));
      return FinanceState.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await _store.clear();
      throw _failure(e);
    } on FormatException {
      throw const ApiFailure('La API devolvió datos con un formato inválido.');
    }
  }

  Future<void> logout() async {
    try {
      _checkUrl();
      final cookie = await _store.read();
      if (cookie != null) {
        await _dio.post<Object?>('/api/logout',
            options: Options(headers: {'Cookie': cookie}));
      }
    } on DioException {
      // Local logout must work offline. Server logout only expires its cookie.
    } finally {
      await _store.clear();
    }
  }

  ApiFailure _failure(DioException e) => switch (e.response?.statusCode) {
        401 => const ApiFailure('Contraseña incorrecta o sesión vencida.',
            unauthorized: true),
        429 => const ApiFailure('Demasiados intentos. Espera 15 minutos.'),
        _ => ApiFailure(e.response == null
            ? 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.'
            : 'El servidor no pudo completar la solicitud. Inténtalo de nuevo.'),
      };
  void close() => _dio.close(force: true);
}
