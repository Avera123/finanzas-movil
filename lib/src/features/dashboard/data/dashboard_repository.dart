import '../../../core/api/backend_client.dart';
import '../domain/dashboard_snapshot.dart';

class DashboardRepository {
  const DashboardRepository(this.client);
  final BackendClient client;
  Future<DashboardSnapshot> load() async {
    final generation = client.sessionGeneration;
    final profile = await client.readProfile();
    _checkSession(generation);
    final document = await client.readDocument();
    _checkSession(generation);
    return DashboardSnapshot(profile, document);
  }

  void _checkSession(int generation) {
    if (generation != client.sessionGeneration) {
      throw const ApiFailure('La sesión cambió. Vuelve a cargar tus datos.',
          unauthorized: true);
    }
  }
}
