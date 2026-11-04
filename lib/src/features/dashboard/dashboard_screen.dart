import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/backend_client.dart';
import '../../core/app_theme.dart';
import 'application/dashboard_controller.dart';
import 'domain/dashboard_snapshot.dart';
import 'domain/month_summary.dart';
import '../movements/domain/finance_commands.dart';
import '../movements/presentation/operation_screen.dart';
import '../movements/presentation/operation_form.dart';
import '../plans/presentation/plans_screen.dart';

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
  Future<void> review(DashboardSnapshot data, String title,
      void Function(FinanceCommands) prepare) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperationScreen(
            document: data.document, title: title, prepare: prepare)));
  }

  Future<Map<String, String>?> form(String title, List<InputSpec> fields) =>
      Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(
          builder: (_) => OperationForm(title: title, fields: fields)));
  double amount(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.')) ?? double.nan;
  Future<void> newExpense(DashboardSnapshot data) async {
    final categories =
        (data.document.fields['cats'] as List? ?? []).cast<String>();
    final methods =
        (data.document.fields['meths'] as List? ?? []).cast<String>();
    if (categories.isEmpty || methods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Primero configura categorías y tipos de pago en la web.')));
      return;
    }
    final result = await form('Nuevo gasto · ${monthLabel(month)}', [
      const InputSpec('name', 'Nombre'),
      const InputSpec('amount', 'Monto COP sin separador de miles',
          numeric: true),
      InputSpec('category', 'Categoría',
          initial: categories.first,
          options: {for (final c in categories) c: c}),
      InputSpec('method', 'Tipo de pago',
          initial: methods.first, options: {for (final m in methods) m: m}),
      InputSpec('account', 'Cuenta', required: false, options: {
        '': 'Sin cuenta',
        for (final a in data.finances.accounts) a.id: a.name
      }),
      const InputSpec('repeat', 'Número de meses (1 a 600)',
          initial: '1', numeric: true),
    ]);
    if (!mounted || result == null) return;
    await review(
        data,
        'Crear gasto: ${result['name']}',
        (commands) => commands.addExpense(
            name: result['name']!,
            amount: amount(result['amount']),
            month: monthKey(month),
            category: result['category']!,
            method: result['method']!,
            account: result['account'] == '' ? null : result['account'],
            repeat: int.tryParse(result['repeat']!) ?? 0));
  }

  Future<void> newAccount(DashboardSnapshot data) async {
    final result = await form('Nueva cuenta', [
      const InputSpec('name', 'Nombre'),
      const InputSpec('type', 'Tipo', initial: 'Ahorros', options: {
        'Ahorros': 'Ahorros',
        'Corriente': 'Corriente',
        'Inversión': 'Inversión',
        'Efectivo': 'Efectivo',
        'Crédito': 'Crédito'
      }),
      const InputSpec('balance', 'Saldo COP sin separador de miles',
          initial: '0', numeric: true)
    ]);
    if (!mounted || result == null) return;
    await review(
        data,
        'Crear cuenta: ${result['name']}',
        (commands) => commands.addAccount(
            result['name']!, result['type']!, amount(result['balance'])));
  }

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
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlansScreen())),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Deudas y préstamos')),
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
      FilledButton.icon(
          onPressed: () => newExpense(data),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo gasto')),
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
              if (row.id != null)
                Wrap(spacing: 8, children: [
                  if (!row.paid)
                    TextButton(
                        onPressed: () async {
                          final result = await form('Cuenta de ${row.name}', [
                            InputSpec('account', 'Cuenta',
                                required: false,
                                initial: row.accountId ?? '',
                                options: {
                                  '': 'Sin cuenta',
                                  for (final a in data.finances.accounts)
                                    a.id: a.name
                                })
                          ]);
                          if (!mounted || result == null) return;
                          final id = result['account']!;
                          await review(
                              data,
                              'Cambiar cuenta: ${row.name}',
                              (c) => c.assignAccount(
                                  row.id!, id.isEmpty ? null : id));
                        },
                        child: const Text('Elegir cuenta')),
                  TextButton(
                      onPressed: () => review(
                          data,
                          '${row.paid ? "Deshacer pago" : "Pagar"}: ${row.name}',
                          (c) => c.togglePayment(row.id!)),
                      child: Text(row.paid ? 'Deshacer pago' : 'Pagar')),
                  if (!row.linkedPlan)
                    TextButton(
                        onPressed: () => review(data, 'Eliminar: ${row.name}',
                            (c) => c.deleteExpense(row.id!)),
                        child: const Text('Eliminar')),
                  if (!row.paid && !row.linkedPlan)
                    TextButton(
                        onPressed: () async {
                          final result = await form(
                              row.series
                                  ? 'Mover serie hacia adelante'
                                  : 'Mover gasto',
                              [
                                InputSpec('month', 'Nuevo mes AAAA-MM',
                                    initial: addMonth(monthKey(month), 1))
                              ]);
                          if (!mounted || result == null) return;
                          await review(
                              data,
                              'Mover ${row.name} a ${result['month']}',
                              (c) => c.move(row.id!, result['month']!,
                                  series: row.series));
                        },
                        child: Text(row.series ? 'Mover serie' : 'Mover mes')),
                ]),
            ]));
      }),
    ];
  }

  List<Widget> accounts(DashboardSnapshot data) => [
        FilledButton.icon(
            onPressed: () => newAccount(data),
            icon: const Icon(Icons.add),
            label: const Text('Nueva cuenta')),
        card('Saldo neto de cuentas', money(data.finances.netBalance)),
        const Text(
            'Saldos actuales guardados. Las cuentas de crédito restan del neto.'),
        const SizedBox(height: 12),
        if (data.finances.accounts.isEmpty)
          const Text('Aún no tienes cuentas. Puedes crearlas en la web.'),
        ...data.finances.accounts.map((a) => card(
            a.name,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.type),
              money(a.balance),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: () async {
                      final result = await form('Editar saldo: ${a.name}', [
                        InputSpec('value', 'Saldo COP sin separador de miles',
                            initial: a.balance.toString(), numeric: true)
                      ]);
                      if (!mounted || result == null) return;
                      await review(
                          data,
                          'Editar saldo: ${a.name}',
                          (c) => c.setAccountBalance(
                              a.id, amount(result['value'])));
                    },
                    child: const Text('Editar saldo')),
                TextButton(
                    onPressed: () async {
                      final result = await form('Ingresar USD: ${a.name}', [
                        const InputSpec('value', 'Monto USD', numeric: true)
                      ]);
                      if (!mounted || result == null) return;
                      await review(
                          data,
                          'Convertir ${result['value']} USD a tasa ${data.document.fields['rate']}',
                          (c) => c.depositUsd(a.id, amount(result['value'])));
                    },
                    child: const Text('Ingresar USD')),
              ])
            ]))),
      ];

  List<Widget> appearance(DashboardSnapshot data) => [
        FilledButton(
            onPressed: () async {
              final result = await form('Ingreso de ${monthLabel(month)}', [
                const InputSpec(
                    'value', 'Ingreso COP; vacío vuelve al salario × tasa',
                    numeric: true, required: false)
              ]);
              if (!mounted || result == null) return;
              final value = result['value']!.trim().isEmpty
                  ? null
                  : amount(result['value']);
              await review(
                  data,
                  'Ingreso ${monthKey(month)}: ${value == null ? "salario × tasa" : cop(value.isFinite ? value : 0)}',
                  (c) => c.setIncome(monthKey(month), value));
            },
            child: Text('Ingreso de ${monthLabel(month)}')),
        for (final key in ['cats', 'meths'])
          card(
              key == 'cats' ? 'Categorías' : 'Tipos de pago',
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final option in (data.document.fields[key] as List? ?? [])
                    .cast<String>())
                  Wrap(alignment: WrapAlignment.spaceBetween, children: [
                    Text(option),
                    TextButton(
                        onPressed: () => review(
                            data,
                            'Eliminar opción: $option',
                            (c) => c.removeOption(key, option)),
                        child: const Text('Eliminar'))
                  ]),
                TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar opción'),
                    onPressed: () async {
                      final result = await form(
                          'Nueva opción', [const InputSpec('value', 'Nombre')]);
                      if (!mounted || result == null) return;
                      await review(data, 'Agregar opción: ${result['value']}',
                          (c) => c.addOption(key, result['value']!));
                    }),
              ])),
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
        const Text('Finanzas Móvil · v0.4.0 (4)\nEtapa 3 · deudas y préstamos'),
      ];

  Widget content(DashboardSnapshot data) {
    List<Widget> children;
    try {
      children = switch (destination) {
        0 => overview(data, MonthSummary(data.document, month)),
        1 => movements(data, MonthSummary(data.document, month)),
        2 => accounts(data),
        _ => appearance(data),
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
