import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/backend_client.dart';
import '../../core/app_theme.dart';
import 'application/dashboard_controller.dart';
import 'domain/dashboard_snapshot.dart';
import 'domain/month_summary.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool signingOut = false;
  bool savingTheme = false;
  int destination = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? category;
  static const destinations = [
    'Resumen',
    'Movimientos',
    'Cuentas',
    'Apariencia'
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.palette_outlined
  ];

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
                'No se pudo borrar la sesión del dispositivo. Inténtalo de nuevo.')));
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  Widget card(String title, Widget child) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child
          ])));

  Widget money(num value) => Text(cop(value),
      style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()]));

  Widget period() => Row(children: [
        IconButton(
            tooltip: 'Mes anterior',
            onPressed: () => changeMonth(-1),
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text(monthLabel(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
            tooltip: 'Mes siguiente',
            onPressed: () => changeMonth(1),
            icon: const Icon(Icons.chevron_right)),
      ]);
  void changeMonth(int offset) => setState(() {
        month = DateTime(month.year, month.month + offset);
        category = null;
      });

  List<Widget> overview(DashboardSnapshot data, MonthSummary summary) => [
        Text(data.profile.name,
            style: Theme.of(context).textTheme.headlineSmall),
        Text(data.profile.email),
        Text(data.profile.role == 'admin' ? 'Administrador' : 'Usuario'),
        const SizedBox(height: 16),
        card(
            'Saldo neto de cuentas · actual',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              money(data.finances.netBalance),
              const SizedBox(height: 8),
              const Text(
                  'Ahorros y efectivo menos cuentas de crédito. No incluye otras deudas ni préstamos.'),
            ])),
        period(),
        card(
            summary.recordedIncome
                ? 'Ingreso registrado'
                : 'Ingreso estimado · salario × tasa',
            summary.income == null
                ? const Text('Configura tu ingreso en la aplicación web.')
                : money(summary.income!)),
        card('Gastos registrados del mes', money(summary.total)),
        card('Pendiente por pagar · gastos del mes', money(summary.pending)),
        if (summary.income != null)
          card(
              'Ingreso menos gastos registrados',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                money(summary.income! - summary.total),
                const Text(
                    'No es un saldo bancario ni una proyección completa: excluye aportes de ahorro y préstamos fuera de gastos.'),
              ])),
        card(
            'Gastos por categoría · toca para ver detalle',
            Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: summary.categories.isEmpty
                    ? [const Text('No hay gastos registrados en este mes.')]
                    : summary.categories.entries
                        .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                                onPressed: () => setState(() {
                                      category = entry.key;
                                      destination = 1;
                                    }),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                              '${entry.key}\n${cop(entry.value)}'),
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                              value: summary.total > 0
                                                  ? (entry.value /
                                                          summary.total)
                                                      .clamp(0, 1)
                                                  : 0,
                                              semanticsLabel: entry.key,
                                              semanticsValue: cop(entry.value)),
                                        ])))))
                        .toList())),
      ];

  List<Widget> movements(DashboardSnapshot data, MonthSummary summary) {
    final rows = summary.expenses
        .where((row) => category == null || row.category == category);
    return [
      period(),
      const Text(
          'Consulta de gastos y cuotas guardados. Los pagos se gestionan en la web durante esta etapa.'),
      if (category != null)
        TextButton.icon(
            onPressed: () => setState(() => category = null),
            icon: const Icon(Icons.filter_alt_off),
            label: Text('Quitar filtro: $category')),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const Text('No hay movimientos para este período y filtro.'),
      ...rows.map((row) {
        final accounts =
            data.finances.accounts.where((a) => a.id == row.accountId);
        return card(
            row.name,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              money(row.amount),
              Text('${row.category} · ${row.paid ? "Pagado" : "Pendiente"}'),
              Text(accounts.isEmpty
                  ? 'Sin cuenta vinculada'
                  : accounts.first.name),
            ]));
      }),
    ];
  }

  List<Widget> accounts(DashboardSnapshot data) => [
        card('Saldo neto de cuentas', money(data.finances.netBalance)),
        const Text(
            'Saldos actuales guardados. Las cuentas de crédito restan del neto.'),
        const SizedBox(height: 12),
        if (data.finances.accounts.isEmpty)
          const Text('Aún no tienes cuentas. Puedes crearlas en la web.'),
        ...data.finances.accounts.map((a) => card(
            a.name,
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(a.type), money(a.balance)]))),
      ];

  List<Widget> appearance() => [
        const Text(
            'Elige el estilo de este dispositivo. Se conserva al cerrar sesión.'),
        const SizedBox(height: 16),
        ...themeNames.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
                icon: Icon(ref.watch(themeProvider) == entry.key
                    ? Icons.check_circle
                    : Icons.circle_outlined),
                onPressed: savingTheme
                    ? null
                    : () async {
                        setState(() => savingTheme = true);
                        final ok = await ref
                            .read(themeProvider.notifier)
                            .select(entry.key);
                        if (!mounted) return;
                        setState(() => savingTheme = false);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'No se pudo guardar la apariencia. Inténtalo de nuevo.')));
                        }
                      },
                label: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(entry.value))))),
        const SizedBox(height: 24),
        const Text(
            'Finanzas Móvil · v0.2.0 (2)\nEtapa 1 · consulta y apariencia'),
      ];

  Widget content(DashboardSnapshot data) {
    List<Widget> children;
    try {
      children = switch (destination) {
        0 => overview(data, MonthSummary(data.document, month)),
        1 => movements(data, MonthSummary(data.document, month)),
        2 => accounts(data),
        _ => appearance(),
      };
    } on FormatException {
      children = [
        const Text(
            'Hay un movimiento con formato incompatible. Revisa los datos en la web y actualiza.')
      ];
    }
    return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeStateProvider);
          try {
            await ref.read(financeStateProvider.future);
          } catch (_) {
            // The provider renders the recoverable error state.
          }
        },
        child: ListView(
            key: ValueKey(destination),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: children));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeStateProvider);
    final wide = MediaQuery.sizeOf(context).width >= 600 &&
        MediaQuery.textScalerOf(context).scale(1) < 1.5;
    final body = state.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final expired = error is ApiFailure && error.unauthorized;
          return Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                        child: Text(expired ? 'Iniciar sesión' : 'Reintentar')),
                  ])));
        },
        data: content);
    return Scaffold(
      appBar: AppBar(title: Text(destinations[destination]), actions: [
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
      body: SafeArea(
          child: Row(children: [
        if (wide)
          NavigationRail(
              selectedIndex: destination,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) =>
                  setState(() => destination = index),
              destinations: List.generate(
                  4,
                  (i) => NavigationRailDestination(
                      icon: Icon(icons[i]), label: Text(destinations[i])))),
        Expanded(child: body),
      ])),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: destination,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) =>
                  setState(() => destination = index),
              destinations: List.generate(
                  4,
                  (i) => NavigationDestination(
                      icon: Icon(icons[i]), label: destinations[i]))),
    );
  }
}
