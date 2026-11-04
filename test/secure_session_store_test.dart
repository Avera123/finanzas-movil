import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/api/backend_client.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Sesión queda aislada por origen de API', () async {
    final first = SecureSessionStore(origin: 'https://first.example.test');
    final second = SecureSessionStore(origin: 'https://second.example.test');
    await first.write(testCookie());
    expect(await first.read(), testCookie());
    expect(await second.read(), isNull);
    await first.clear();
    expect(await first.read(), isNull);
  });
  test('No reutiliza la cookie global del scaffold y la elimina', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'backend_session_cookie': testCookie()});
    final store = SecureSessionStore(origin: 'https://first.example.test');
    expect(await store.read(), isNull);
    expect(
        await const FlutterSecureStorage().read(key: 'backend_session_cookie'),
        isNull);
  });
  test('Logout elimina también la cookie del scaffold anterior', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'backend_session_cookie': testCookie()});
    final store = SecureSessionStore(origin: 'https://first.example.test');
    await store.write(testCookie());
    await store.clear();
    expect(await store.read(), isNull);
    expect(
        await const FlutterSecureStorage().read(key: 'backend_session_cookie'),
        isNull);
  });
}
