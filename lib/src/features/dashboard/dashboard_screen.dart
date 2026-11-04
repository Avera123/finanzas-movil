import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/backend_client.dart';

final financeStateProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(backendClientProvider).readState(),
);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(financeStateProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(backendClientProvider).logout();
              ref.invalidate(financeStateProvider);
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('No se pudieron cargar los datos'),
            TextButton(
              onPressed: () => ref.invalidate(financeStateProvider),
              child: const Text('Reintentar'),
            ),
          ]),
        ),
        data: (data) {
          final accounts = (data['acc'] as List<dynamic>? ?? []);
          final expenses = (data['exp'] as List<dynamic>? ?? []);
          final net = accounts.fold<double>(0, (sum, item) {
            final account = item as Map<String, dynamic>;
            final balance = (account['bal'] as num?)?.toDouble() ?? 0;
            return sum + (account['type'] == 'Crédito' ? -balance : balance);
          });
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('Saldo neto de cuentas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('\$ ${net.toStringAsFixed(0)} COP',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Text('Cuentas: ${accounts.length}'),
            Text('Gastos registrados: ${expenses.length}'),
            const SizedBox(height: 16),
            const Text('Primera versión de consulta. Los datos no se modifican desde la app.'),
          ]);
        },
      ),
    );
  }
}
