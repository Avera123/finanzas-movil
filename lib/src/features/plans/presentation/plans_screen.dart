import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/backend_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../dashboard/domain/month_summary.dart';
import '../../movements/presentation/operation_form.dart';
import '../../movements/presentation/operation_screen.dart';
import '../domain/plan_commands.dart';
import '../domain/plan_engine.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});
  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String get now => monthKey(DateTime.now());
  String get today => civilToday(DateTime.now());
  bool loans = false;
  double amount(String? text) =>
      double.tryParse((text ?? '').replaceAll(',', '.')) ?? double.nan;
  Future<Map<String, String>?> form(String title, List<InputSpec> fields) =>
      Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(
          builder: (_) => OperationForm(title: title, fields: fields)));
  Future<void> review(DashboardSnapshot snapshot, String title,
          void Function(PlanCommands) change) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => OperationScreen(
              document: snapshot.document,
              title: title,
              prepare: (commands) => change(PlanCommands(commands)))));
  InputSpec accountField(DashboardSnapshot data, [String initial = '']) =>
      InputSpec('account', 'Cuenta',
          initial: initial,
          required: false,
          options: {
            '': 'Sin cuenta',
            for (final a in data.finances.accounts) a.id: a.name
          });
  String? nullable(String? value) =>
      value == null || value.isEmpty ? null : value;
  Future<void> debtForm(DashboardSnapshot data, [Map? debt]) async {
    final pendingNames = records(data.document.fields, 'exp')
        .where((e) =>
            e['paid'] != true &&
            e['debtId'] == null &&
            e['investId'] == null &&
            (e['m'] as String).compareTo(now) >= 0)
        .map((e) => e['name'] as String)
        .toSet();
    final mode = debt?['mode'] == 'fixed'
        ? 'cuota'
        : debt?['mode'] as String? ?? 'cuota';
    final result =
        await form(debt == null ? 'Registrar deuda' : 'Editar deuda', [
      InputSpec('name', 'A quién le debes',
          initial: debt?['name'] as String? ?? ''),
      InputSpec('mode', 'Cómo pagar', initial: mode, options: const {
        'cuota': 'Cuota fija',
        'known': 'Cuota y plazo conocidos',
        'months': 'Dividir en meses',
        'fast': 'Menor tiempo posible',
        'open': 'Solo cuota, saldo desconocido'
      }),
      InputSpec('total', 'Monto inicial COP (0 si desconocido)',
          initial: '${debt?['total'] ?? 0}', numeric: true),
      InputSpec(
          'rate', 'Interés mensual % (se infiere en cuota y plazo conocidos)',
          initial: '${debt?['rate'] ?? 0}', numeric: true),
      InputSpec('value', 'Cuota COP (0 si dividir en meses o menor tiempo)',
          initial: '${debt?['cuota'] ?? 0}', numeric: true),
      const InputSpec(
          'count', 'Plazo en meses (solo dividir o cuota y plazo conocidos)',
          initial: '12', numeric: true),
      InputSpec('start', 'Mes inicial AAAA-MM',
          initial: debt?['startM'] as String? ?? now),
      InputSpec('end', 'Mes final opcional para cuota abierta',
          initial: debt?['endM'] as String? ?? '', required: false),
      accountField(data, debt?['acc'] as String? ?? ''),
      if (debt == null)
        InputSpec('replace', 'Reemplazar gastos pendientes del mismo nombre',
            required: false,
            options: {
              '': 'No reemplazar',
              for (final name in pendingNames) name: name
            }),
    ]);
    if (!mounted || result == null) return;
    await review(
        data,
        'Plan de deuda: ${result['name']}',
        (c) => c.saveDebt(
            id: debt?['id'] as String?,
            name: result['name']!,
            mode: result['mode']!,
            total: amount(result['total']),
            rate: amount(result['rate']),
            value: result['mode'] == 'months'
                ? amount(result['count'])
                : amount(result['value']),
            count: int.tryParse(result['count']!) ?? 0,
            start: result['start']!,
            end: nullable(result['end']),
            account: nullable(result['account']),
            replaceName: nullable(result['replace']),
            now: now));
  }

  Future<void> loanForm(DashboardSnapshot data) async {
    final result = await form('Registrar dinero prestado', [
      const InputSpec('person', 'A quién le prestaste'),
      const InputSpec('total', 'Monto COP sin separador de miles',
          numeric: true),
      InputSpec('lentOn', 'Fecha de préstamo AAAA-MM-DD', initial: today),
      const InputSpec('dueOn', 'Fecha de devolución AAAA-MM-DD'),
      accountField(data),
      const InputSpec('note', 'Nota opcional', required: false)
    ]);
    if (!mounted || result == null) return;
    await review(
        data,
        'Préstamo a ${result['person']}',
        (c) => c.createLoan(
            result['person']!,
            amount(result['total']),
            result['lentOn']!,
            result['dueOn']!,
            nullable(result['account']),
            result['note']!));
  }

  Widget debtCard(DashboardSnapshot snapshot, Map debt) {
    final data = snapshot.document.fields;
    final rows = records(data, 'exp')
        .where((e) => e['debtId'] == debt['id'])
        .toList()
      ..sort((a, b) => (a['m'] as String).compareTo(b['m'] as String));
    final pending = rows.where((e) => e['paid'] != true).toList();
    final paid = rows.where((e) => e['paid'] == true).toList();
    final open = debt['mode'] == 'open';
    final month = now.compareTo(debt['startM'] as String) < 0
        ? debt['startM'] as String
        : now;
    final balance = open ? null : debtBalance(data, debt, month, '9999-12');
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(debt['name'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(open
                  ? 'Saldo desconocido · cuota ${cop(number(debt['cuota']))}'
                  : 'Saldo actual: ${cop(balance!)}'),
              Text(
                  'Pagado: ${cop(sumRows(paid))} · ${pending.length} cuotas pendientes'),
              Text(open
                  ? 'Sin saldo total conocido'
                  : 'Interés mensual: ${debt['rate']} %'),
              if (pending.isNotEmpty)
                Text(
                    'Hasta ${pending.last['m']} · ${pending.map((e) => e['m']).toSet().length} meses con pagos'),
              if (pending.any((e) => (e['m'] as String).compareTo(now) < 0))
                const Text('Hay cuotas vencidas. Revisa o reprograma el plan.'),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: () => debtForm(snapshot, debt),
                    child: const Text('Editar y recalcular')),
                TextButton(
                    onPressed: () => review(
                        snapshot,
                        'Eliminar ${debt['name']} y conservar pagos hechos',
                        (c) => c.removeDebt(debt['id'] as String)),
                    child: const Text('Eliminar deuda')),
                if (!open)
                  TextButton(
                      onPressed: () => review(
                          snapshot,
                          'Menor tiempo: ${debt['name']}',
                          (c) => c.fastest(debt['id'] as String, now)),
                      child: const Text('Calcular menor tiempo')),
                if (!open)
                  TextButton(
                      onPressed: () async {
                        final result = await form('Abono extra', [
                          const InputSpec('amount', 'Abono COP', numeric: true)
                        ]);
                        if (!mounted || result == null) return;
                        await review(
                            snapshot,
                            'Abonar a ${debt['name']}',
                            (c) => c.extraPayment(debt['id'] as String,
                                amount(result['amount']), now));
                      },
                      child: const Text('Abonar')),
                if (pending.isNotEmpty)
                  TextButton(
                      onPressed: () async {
                        final result = await form('Aplazar cuotas pendientes', [
                          const InputSpec(
                              'months', 'Meses hacia adelante (1 a 600)',
                              initial: '1', numeric: true)
                        ]);
                        if (!mounted || result == null) return;
                        await review(
                            snapshot,
                            'Aplazar ${debt['name']}; el interés sigue corriendo',
                            (c) => c.shiftDebt(debt['id'] as String,
                                int.tryParse(result['months']!) ?? 0, now));
                      },
                      child: const Text('Mover cuotas')),
              ]),
              if (!open)
                ExpansionTile(
                    title: const Text('Proyección de saldo · 12 meses'),
                    children: List.generate(12, (index) {
                      final month = DateTime(
                          DateTime.now().year, DateTime.now().month + index);
                      return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                              '${monthLabel(month)}: ${cop(debtBalance(data, debt, monthKey(month), now))} si pagas las cuotas previstas'));
                    })),
              ExpansionTile(
                  title: const Text('Ver cuotas y pagos'),
                  children: rows
                      .map((row) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${row['m']} · ${cop(number(row['amt']))} · ${row['paid'] == true ? "Pagado" : "Pendiente"}'),
                                Wrap(children: [
                                  TextButton(
                                      onPressed: () => review(
                                          snapshot,
                                          '${row['paid'] == true ? "Deshacer" : "Pagar"} cuota ${row['m']}',
                                          (c) => c.commands.togglePayment(
                                              row['id'] as String)),
                                      child: Text(row['paid'] == true
                                          ? 'Deshacer pago'
                                          : 'Pagar')),
                                  if (open && row['paid'] != true)
                                    TextButton(
                                        onPressed: () async {
                                          final result = await form(
                                              'Ajustar cuota de ${row['m']}', [
                                            InputSpec('amount', 'Cuota COP',
                                                initial: '${row['amt']}',
                                                numeric: true)
                                          ]);
                                          if (!mounted || result == null) {
                                            return;
                                          }
                                          await review(
                                              snapshot,
                                              'Cuota de ${row['m']}',
                                              (c) => c.setOpenAmount(
                                                  row['id'] as String,
                                                  amount(result['amount'])));
                                        },
                                        child: const Text('Cambiar monto')),
                                ]),
                              ])))
                      .toList()),
            ])));
  }

  Widget loanCard(DashboardSnapshot snapshot, Map loan) {
    final data = snapshot.document.fields;
    final balance = loanBalance(data, loan);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loan['person'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Por cobrar: ${cop(balance)}'),
              Text(loanDueLabel(data, loan, today)),
              Text('Prestado ${loan['lentOn']} · devolución ${loan['dueOn']}'),
              if (loan['note'] != null) Text(loan['note'] as String),
              Wrap(spacing: 8, children: [
                if (balance >= 1)
                  TextButton(
                      onPressed: () async {
                        final result = await form('Registrar cobro', [
                          const InputSpec('amount', 'Monto recibido COP',
                              numeric: true),
                          InputSpec('on', 'Fecha AAAA-MM-DD', initial: today),
                          accountField(snapshot)
                        ]);
                        if (!mounted || result == null) return;
                        await review(
                            snapshot,
                            'Cobro a ${loan['person']}',
                            (c) => c.receiveLoan(
                                loan['id'] as String,
                                amount(result['amount']),
                                result['on']!,
                                nullable(result['account'])));
                      },
                      child: const Text('Recibí un pago')),
                TextButton(
                    onPressed: () async {
                      final result = await form('Fecha de devolución', [
                        InputSpec('on', 'Fecha AAAA-MM-DD',
                            initial: loan['dueOn'] as String)
                      ]);
                      if (!mounted || result == null) return;
                      await review(
                          snapshot,
                          'Cambiar vencimiento de ${loan['person']}',
                          (c) => c.changeLoanDate(
                              loan['id'] as String, result['on']!));
                    },
                    child: const Text('Cambiar fecha')),
                TextButton(
                    onPressed: () => review(
                        snapshot,
                        'Eliminar préstamo y revertir movimientos en cuentas',
                        (c) => c.removeLoan(loan['id'] as String)),
                    child: const Text('Eliminar')),
              ]),
              for (final receipt in records(data, 'loanPay')
                  .where((p) => p['loanId'] == loan['id']))
                Wrap(spacing: 8, children: [
                  Text('${receipt['on']} · ${cop(number(receipt['amt']))}'),
                  TextButton(
                      onPressed: () => review(
                          snapshot,
                          'Deshacer cobro de ${loan['person']}',
                          (c) => c.undoLoanReceipt(receipt['id'] as String)),
                      child: const Text('Deshacer cobro'))
                ]),
            ])));
  }

  Widget loaded(DashboardSnapshot snapshot) {
    try {
      final items =
          records(snapshot.document.fields, loans ? 'loans' : 'debts');
      final detected = records(snapshot.document.fields, 'exp')
          .where((e) =>
              e['paid'] != true &&
              e['debtId'] == null &&
              e['investId'] == null &&
              (e['m'] as String).compareTo(now) >= 0 &&
              (e['cat'] == 'Deuda' ||
                  RegExp(r'cuota|alkomprar|cr[eé]dito', caseSensitive: false)
                      .hasMatch(e['name'] as String)))
          .map((e) => e['name'] as String)
          .toSet();
      return ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('Deudas que debo'),
              selected: !loans,
              onSelected: (_) => setState(() => loans = false)),
          ChoiceChip(
              label: const Text('Dinero que me deben'),
              selected: loans,
              onSelected: (_) => setState(() => loans = true))
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: () => loans ? loanForm(snapshot) : debtForm(snapshot),
            icon: const Icon(Icons.add),
            label: Text(loans ? 'Registrar préstamo' : 'Registrar deuda')),
        if (!loans)
          TextButton(
              onPressed: () => review(
                  snapshot,
                  'Generar cuotas abiertas de próximos 12 meses',
                  (c) => c.extendOpen(now)),
              child: const Text('Extender cuotas abiertas')),
        if (!loans)
          TextButton(
              onPressed: () async {
                final result = await form('Presupuesto para plazo mínimo', [
                  InputSpec(
                      'living', 'Gasto de vida mensual COP; vacío usa promedio',
                      initial: '${snapshot.document.fields['living'] ?? ''}',
                      required: false,
                      numeric: true)
                ]);
                if (!mounted || result == null) return;
                await review(
                    snapshot,
                    'Presupuesto de vida: ${result['living']!.isEmpty ? "promedio de últimos 3 meses con registros" : result['living']}',
                    (c) => c.setLiving(result['living']!.isEmpty
                        ? null
                        : amount(result['living'])));
              },
              child: const Text('Configurar gasto de vida para plazo mínimo')),
        if (!loans && detected.isNotEmpty)
          ExpansionTile(
              title: const Text('Cuotas encontradas en gastos'),
              children: detected
                  .map((name) => TextButton(
                      onPressed: () => review(
                          snapshot,
                          'Mantener $name mes a mes; saldo desconocido',
                          (c) => c.convertOpen(name, now)),
                      child: Text('Convertir $name en cuota abierta')))
                  .toList()),
        if (items.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay registros en esta sección.')),
        ...items.map((item) =>
            loans ? loanCard(snapshot, item) : debtCard(snapshot, item)),
      ]);
    } catch (_) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No se pudieron interpretar los planes. Revisa los datos en la web y actualiza.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Deudas y préstamos'), actions: [
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
                          : 'No se pudieron cargar. Reintentar'))),
              data: loaded)));
}
