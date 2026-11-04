import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/finance_state.dart';
import '../models/user_profile.dart';

const backendUrl = String.fromEnvironment('API_BASE_URL');
final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
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
    // Multiuser contract: userId.sessionVersion.expiryMs.hmac.
    // The HMAC and account status/version are validated ONLY by the server.
    final match =
        RegExp(r'^sesion=([A-Za-z0-9_-]+)\.([1-9]\d*)\.(\d+)\.([a-f0-9]{64})$')
            .firstMatch(value);
    final expiry = match == null ? null : int.tryParse(match.group(3)!);
    return expiry != null && expiry > _now().millisecondsSinceEpoch;
  }

  Future<bool> hasSession() async {
    final cookie = await _store.read();
    if (cookie == null) return false;
    if (_validCookie(cookie)) return true;
    await _store.clear();
    return false;
  }

  Future<void> login(String email, String password) async {
    _checkUrl();
    final normalizedEmail = email.trim().toLowerCase();
    if (!emailPattern.hasMatch(normalizedEmail)) {
      throw const ApiFailure('Escribe un correo válido.');
    }
    if (password.trim().isEmpty) {
      throw const ApiFailure('Escribe tu contraseña.');
    }
    await _store.clear();
    try {
      final response = await _dio.post<Object?>('/api/login',
          data: {'email': normalizedEmail, 'password': password});
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
      throw _failure(e, login: true);
    } on FormatException {
      throw const ApiFailure('El servidor no devolvió una sesión válida.');
    } on HttpException {
      throw const ApiFailure('El servidor no devolvió una sesión válida.');
    }
  }

  Future<FinanceState> readState() async {
    final data = await _getAuthenticated('/api/state');
    try {
      return FinanceState.fromJson(data);
    } on FormatException {
      throw const ApiFailure('La API devolvió datos con un formato inválido.');
    }
  }

  Future<UserProfile> readProfile() async {
    final data = await _getAuthenticated('/api/me');
    try {
      return UserProfile.fromJson(data);
    } on FormatException {
      throw const ApiFailure(
          'La API devolvió un perfil con un formato inválido.');
    }
  }

  Future<Object?> _getAuthenticated(String path) async {
    _checkUrl();
    if (!await hasSession()) {
      throw const ApiFailure('Inicia sesión para continuar.',
          unauthorized: true);
    }
    final cookie = await _store.read();
    try {
      final response = await _dio.get<Object?>(path,
          options: Options(headers: {'Cookie': cookie}));
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await _store.clear();
      throw _failure(e);
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

  ApiFailure _failure(DioException e, {bool login = false}) =>
      switch (e.response?.statusCode) {
        401 => ApiFailure(
            login
                ? 'Correo o contraseña incorrectos.'
                : 'Tu sesión venció o fue revocada. Vuelve a iniciar sesión.',
            unauthorized: true),
        403 =>
          const ApiFailure('No tienes permiso para realizar esta consulta.'),
        429 => const ApiFailure('Demasiados intentos. Espera 15 minutos.'),
        _ => ApiFailure(e.response == null
            ? 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.'
            : 'El servidor no pudo completar la solicitud. Inténtalo de nuevo.'),
      };
  void close() => _dio.close(force: true);
}
