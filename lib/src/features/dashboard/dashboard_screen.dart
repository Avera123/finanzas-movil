import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/backend_client.dart';
import '../../core/models/finance_state.dart';
import '../../core/models/user_profile.dart';

class DashboardData {
  const DashboardData(this.profile, this.finances);
  final UserProfile profile;
  final FinanceState finances;
}

final financeStateProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final client = ref.watch(backendClientProvider);
  final profile = await client.readProfile();
  final finances = await client.readState();
  return DashboardData(profile, finances);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool signingOut = false;
  Future<void> logout() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await ref.read(backendClientProvider).logout();
      ref.invalidate(financeStateProvider);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No se pudo borrar la sesión del dispositivo. Inténtalo de nuevo.'),
        ));
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen'), actions: [
        IconButton(
            tooltip: 'Actualizar',
            onPressed:
                signingOut ? null : () => ref.invalidate(financeStateProvider),
            icon: const Icon(Icons.refresh)),
        IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: signingOut ? null : logout,
            icon: const Icon(Icons.logout)),
      ]),
      body: state.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final expired = error is ApiFailure && error.unauthorized;
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error is ApiFailure
                          ? error.message
                          : 'No se pudieron cargar los datos.'),
                      TextButton(
                          onPressed: expired
                              ? () {
                                  ref.invalidate(financeStateProvider);
                                  context.go('/login');
                                }
                              : () => ref.invalidate(financeStateProvider),
                          child:
                              Text(expired ? 'Iniciar sesión' : 'Reintentar')),
                    ],
                  )));
        },
        data: (data) => ListView(padding: const EdgeInsets.all(20), children: [
          Text(data.profile.name,
              style: Theme.of(context).textTheme.titleLarge),
          Text(data.profile.email),
          Text(data.profile.role == 'admin' ? 'Administrador' : 'Usuario'),
          const SizedBox(height: 20),
          Text('Saldo neto de cuentas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('\$ ${data.finances.netBalance.toStringAsFixed(0)} COP',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Text('Cuentas: ${data.finances.accounts.length}'),
          Text('Gastos registrados: ${data.finances.expenseCount}'),
          const SizedBox(height: 16),
          const Text(
              'Ahorros y efectivo menos cuentas de crédito. No incluye otras deudas ni préstamos.'),
        ]),
      ),
    );
  }
}
