import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/backend_client.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_snapshot.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(backendClientProvider)),
);
final financeStateProvider = FutureProvider.autoDispose<DashboardSnapshot>(
  (ref) => ref.watch(dashboardRepositoryProvider).load(),
);
