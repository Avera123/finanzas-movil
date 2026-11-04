import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/backend_client.dart';
import 'application/dashboard_controller.dart';
import 'domain/dashboard_snapshot.dart';
import 'domain/month_summary.dart';
import 'domain/annual_projection.dart';
import '../plans/domain/plan_engine.dart';
import '../movements/domain/finance_commands.dart';
import '../movements/presentation/operation_form.dart';
import '../movements/presentation/operation_screen.dart';

class AnnualScreen extends ConsumerStatefulWidget {
  const AnnualScreen({super.key, this.today});
  final DateTime? today;
  @override
  ConsumerState<AnnualScreen> createState() => _AnnualScreenState();
}

class _AnnualScreenState extends ConsumerState<AnnualScreen> {
  late final now = monthKey(widget.today ?? DateTime.now());
  late String from = addMonth(now, -5);
  String? selected;
  final horizontal = ScrollController();

  Future<void> editIncome(DashboardSnapshot snapshot, String month) async {
    final original = (snapshot.document.fields['inc'] as Map?)?[month];
    final result =
        await Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(
            builder: (_) => OperationForm(title: 'Ingreso de $month', fields: [
                  InputSpec(
                      'value', 'Ingreso COP; vacío vuelve al salario × tasa',
                      initial: original?.toString() ?? '',
                      numeric: true,
                      required: false)
                ])));
    if (!mounted || result == null) return;
    final text = result['value']!.trim();
    final value = text.isEmpty
        ? null
        : double.tryParse(text.replaceAll(',', '.')) ?? double.nan;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperationScreen(
            document: snapshot.document,
            title: 'Revisar ingreso de $month',
            prepare: (c) => c.setIncome(month, value))));
  }

  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  Widget loaded(DashboardSnapshot snapshot) {
    try {
      final data = snapshot.document.fields;
      final months = List.generate(12, (i) => addMonth(from, i));
      final rows = months.map((m) => annualMonth(data, m, now)).toList();
      final flows = <String, double>{
        for (final k in annualFlows.keys)
          k: rows.fold(0.0, (sum, r) => sum + r[k]!)
      };
      final groups = <String, List<double>>{};
      final pending = <String, Set<int>>{};
      for (final e in records(data, 'exp')) {
        final i = months.indexOf(e['m'] as String);
        if (i < 0) continue;
        final label = '${e['cat']} · ${e['name']}';
        (groups[label] ??= List.filled(12, 0))[i] += number(e['amt']);
        if (e['paid'] != true) (pending[label] ??= <int>{}).add(i);
      }
      DataRow metric(String label, List<double> values, double? total,
              [Set<int> unpaid = const {}]) =>
          DataRow(cells: [
            DataCell(Text(label)),
            for (var i = 0; i < 12; i++)
              DataCell(Text(
                  '${cop(values[i])}${unpaid.contains(i) ? ' · pendiente' : ''}')),
            DataCell(Text(total == null ? '—' : cop(total))),
          ]);
      final tableRows = <DataRow>[
        for (final entry in annualFlows.entries)
          metric(entry.value, rows.map((r) => r[entry.key]!).toList(),
              flows[entry.key]),
        for (final entry in annualStocks.entries)
          metric(entry.value, rows.map((r) => r[entry.key]!).toList(), null),
        metric(
            'Cambio de deuda',
            List.generate(
                12,
                (i) =>
                    rows[i]['debtEnd']! -
                    (i == 0
                        ? annualMonth(data, addMonth(from, -1), now)['debtEnd']!
                        : rows[i - 1]['debtEnd']!)),
            null),
        for (final key in (groups.keys.toList()..sort()))
          metric(
              key,
              groups[key]!,
              groups[key]!.fold<double>(0, (a, b) => a + b),
              pending[key] ?? {}),
      ];
      final pick = selected == null ? null : annualMonth(data, selected!, now);
      return ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          IconButton(
              tooltip: 'Seis meses antes',
              onPressed: () => setState(() {
                    from = addMonth(from, -6);
                    selected = null;
                  }),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child:
                  Text('$from a ${months.last}', textAlign: TextAlign.center)),
          IconButton(
              tooltip: 'Seis meses después',
              onPressed: () => setState(() {
                    from = addMonth(from, 6);
                    selected = null;
                  }),
              icon: const Icon(Icons.chevron_right)),
        ]),
        const Text(
            'Proyección, no saldo bancario. Los meses futuros incluyen gasto base y cobros previstos al vencimiento. Los cobros no están garantizados. El ahorro al cierre incluye a todos los participantes; el gasto de ahorro solo incluye tus aportes.'),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    'Ingresos: ${cop(flows['income']!)}\nGastos y aportes: ${cop(flows['total']!)}\nA favor / en contra: ${cop(flows['left']!)}\nDeuda al final: ${cop(rows.last['debtEnd']!)}'))),
        const Text('Elige un mes para ver sus pagos'),
        Wrap(spacing: 8, children: [
          for (final m in months)
            ChoiceChip(
                label: Text(
                    '$m${m == now ? ' · actual' : m.compareTo(now) > 0 ? ' · proyección' : ''}'),
                selected: selected == m,
                onSelected: (_) =>
                    setState(() => selected = selected == m ? null : m))
        ]),
        if (pick != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Detalle de $selected',
                            style: Theme.of(context).textTheme.titleLarge),
                        OutlinedButton(
                            onPressed: () => editIncome(snapshot, selected!),
                            child: const Text('Editar ingreso del mes')),
                        Text(
                            'A favor / en contra: ${cop(pick['left']!)}\nGasto base estimado incluido: ${cop(pick['estimated']!)}'),
                        if (!records(data, 'exp')
                            .any((e) => e['m'] == selected))
                          const Text('Sin pagos registrados.'),
                        for (final e in records(data, 'exp')
                            .where((e) => e['m'] == selected))
                          Text(
                              '${e['name']} · ${cop(number(e['amt']))} · ${e['paid'] == true ? 'pagado' : 'pendiente'}'),
                      ]))),
        const SizedBox(height: 16),
        const Text(
            'Tabla anual · desliza horizontalmente. Los saldos al cierre no se suman. Aportes invertidos excluye rendimientos estimados.'),
        Scrollbar(
            controller: horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
                controller: horizontal,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 20),
                child: DataTable(
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: double.infinity,
                    columns: [
                      const DataColumn(label: Text('Concepto')),
                      for (final m in months)
                        DataColumn(label: Text(m), numeric: true),
                      const DataColumn(
                          label: Text('Total flujos'), numeric: true),
                    ],
                    rows: tableRows))),
      ]);
    } catch (_) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No se pudo calcular la proyección. Revisa los datos y actualiza.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Resumen anual'), actions: [
        IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(financeStateProvider),
            icon: const Icon(Icons.refresh))
      ]),
      body: SafeArea(
          child: ref.watch(financeStateProvider).when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                  child: TextButton(
                      onPressed: () {
                        if (error is ApiFailure && error.unauthorized) {
                          context.go('/login');
                        } else {
                          ref.invalidate(financeStateProvider);
                        }
                      },
                      child: Text(error is ApiFailure && error.unauthorized
                          ? 'Iniciar sesión'
                          : 'No se pudo cargar. Reintentar'))),
              data: loaded)));
}
