import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/backend_client.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../../dashboard/domain/dashboard_snapshot.dart';
import '../../dashboard/domain/month_summary.dart';
import '../../movements/presentation/operation_form.dart';
import '../../movements/presentation/operation_screen.dart';
import '../domain/capital_commands.dart';
import '../domain/capital_engine.dart';
import '../domain/plan_engine.dart';

class CapitalScreen extends ConsumerStatefulWidget {
  const CapitalScreen({super.key});
  @override
  ConsumerState<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends ConsumerState<CapitalScreen> {
  bool investments = false;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String get now => monthKey(DateTime.now());
  String? nullable(String? value) =>
      value == null || value.isEmpty ? null : value;
  double amount(String? value) =>
      double.tryParse((value ?? '').replaceAll(',', '.')) ?? double.nan;
  Future<Map<String, String>?> form(String title, List<InputSpec> fields) =>
      Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(
          builder: (_) => OperationForm(title: title, fields: fields)));
  Future<void> review(DashboardSnapshot data, String title,
          void Function(CapitalCommands) prepare) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => OperationScreen(
              document: data.document,
              title: title,
              prepare: (c) => prepare(CapitalCommands(c)))));
  InputSpec account(DashboardSnapshot data, String key, String label,
          [String? initial]) =>
      InputSpec(key, label, required: false, initial: initial ?? '', options: {
        '': 'Sin cuenta',
        for (final a in data.finances.accounts) a.id: a.name
      });
  Future<void> investmentForm(DashboardSnapshot data, [Map? inv]) async {
    final result =
        await form(inv == null ? 'Nueva inversión' : 'Editar inversión', [
      InputSpec('name', 'Nombre', initial: inv?['name'] as String? ?? ''),
      InputSpec('kind', 'Tipo',
          initial: inv?['kind'] as String? ?? 'Fondo',
          options: {
            for (final k in [
              'CDT',
              'Fondo',
              'Acciones',
              'Cripto',
              'Finca raíz',
              'Otra'
            ])
              k: k
          }),
      InputSpec('mode', 'Cómo calcular cuota',
          initial: inv?['mode'] as String? ?? 'fixed',
          options: const {
            'fixed': 'Valor fijo',
            'percent': 'Porcentaje del ingreso',
            'goal': 'Meta con fecha'
          }),
      InputSpec('value', 'Monto COP o porcentaje (0 si meta)',
          initial: '${inv?['value'] ?? 0}', numeric: true),
      InputSpec('start', 'Inicio AAAA-MM',
          initial: inv?['startM'] as String? ?? now),
      InputSpec('months', 'Número de meses (1 a 600)',
          initial: '${inv?['months'] ?? 12}', numeric: true),
      InputSpec('rate', 'Rendimiento anual esperado %; no garantizado',
          initial: '${inv?['rate'] ?? 0}', numeric: true),
      const InputSpec('target', 'Meta COP (solo modalidad meta)',
          required: false, numeric: true),
      const InputSpec('goalMonth', 'Mes objetivo AAAA-MM (solo modalidad meta)',
          required: false),
      account(data, 'account', 'Cuenta de origen', inv?['acc'] as String?),
    ]);
    if (!mounted || result == null) return;
    await review(
        data,
        'Proyección de ${result['name']}; rendimiento estimado',
        (c) => c.saveInvestment(
            id: inv?['id'] as String?,
            name: result['name']!,
            kind: result['kind']!,
            mode: result['mode']!,
            value: amount(result['value']),
            months: int.tryParse(result['months']!) ?? 0,
            rate: amount(result['rate']),
            start: result['start']!,
            now: now,
            account: nullable(result['account']),
            target: nullable(result['target']) == null
                ? null
                : amount(result['target']),
            goalMonth: nullable(result['goalMonth'])));
  }

  Future<void> savingForm(DashboardSnapshot data, [Map? saving]) async {
    final members = saving == null
        ? <Map>[]
        : records(saving, 'members').where((p) => p['mine'] == true).toList();
    final own = members.isEmpty ? null : members.first;
    final result =
        await form(saving == null ? 'Nuevo ahorro' : 'Editar ahorro', [
      InputSpec('name', 'Nombre', initial: saving?['name'] as String? ?? ''),
      InputSpec('bank', 'Banco o lugar',
          initial: saving?['bank'] as String? ?? '', required: false),
      InputSpec('start', 'Saldo inicial COP',
          initial: '${saving?['start'] ?? 0}', numeric: true),
      InputSpec('startM', 'Inicio AAAA-MM',
          initial: saving?['startM'] as String? ?? now),
      InputSpec('endM', 'Fin AAAA-MM (opcional)',
          initial: saving?['endM'] as String? ?? '', required: false),
      InputSpec('target', 'Meta COP (opcional)',
          initial: '${saving?['target'] ?? ''}',
          numeric: true,
          required: false),
      InputSpec('monthly', 'Tu aporte mensual COP',
          initial: '${own?['monthly'] ?? 0}', numeric: true),
      account(data, 'fundAccount', 'Cuenta donde está el ahorro',
          saving?['acc'] as String?),
      account(data, 'sourceAccount', 'Cuenta de donde sale tu aporte',
          own?['acc'] as String?),
    ]);
    if (!mounted || result == null) return;
    await review(
        data,
        'Ahorro ${result['name']} y calendario de aportes',
        (c) => c.saveSaving(
            id: saving?['id'] as String?,
            name: result['name']!,
            bank: result['bank']!,
            start: amount(result['start']),
            startMonth: result['startM']!,
            endMonth: nullable(result['endM']),
            target: nullable(result['target']) == null
                ? null
                : amount(result['target']),
            account: nullable(result['fundAccount']),
            ownAccount: nullable(result['sourceAccount']),
            ownMonthly: amount(result['monthly']),
            ownerEmail: data.profile.email,
            now: now));
  }

  Future<void> memberForm(DashboardSnapshot data, Map saving,
      [Map? member]) async {
    final result =
        await form(member == null ? 'Agregar persona' : 'Editar persona', [
      InputSpec('name', 'Nombre', initial: member?['name'] as String? ?? ''),
      InputSpec('email', 'Correo para compartir (opcional)',
          initial: member?['email'] as String? ?? '', required: false),
      InputSpec('monthly', 'Aporte mensual COP',
          initial: '${member?['monthly'] ?? 0}', numeric: true)
    ]);
    if (!mounted || result == null) return;
    await review(
        data, 'Participación de ${result['name']} en ${saving['name']}', (c) {
      if (member == null) {
        c.addMember(saving['id'] as String, result['name']!, result['email']!,
            amount(result['monthly']), now);
      } else {
        c.editMember(saving['id'] as String, member['id'] as String,
            result['name']!, result['email']!, amount(result['monthly']), now);
      }
    });
  }

  Widget investmentCard(DashboardSnapshot data, Map inv) {
    final rows = records(data.document.fields, 'exp')
        .where((e) => e['investId'] == inv['id'])
        .toList()
      ..sort((a, b) => (a['m'] as String).compareTo(b['m'] as String));
    final path = investmentPath(data.document.fields, inv);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inv['name'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  '${inv['kind']} · ${inv['mode'] == 'percent' ? '${inv['value']} % del ingreso' : cop(number(inv['value']))}'),
              Text(
                  'Pagado: ${cop(sumRows(rows.where((e) => e['paid'] == true)))} · pendiente: ${cop(sumRows(rows.where((e) => e['paid'] != true)))}'),
              if (path.isNotEmpty)
                Text(
                    'Valor final estimado: ${cop(number(path.last['value']))}. El rendimiento no está garantizado.'),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: () => investmentForm(data, inv),
                    child: const Text('Editar')),
                TextButton(
                    onPressed: () => review(
                        data,
                        'Eliminar ${inv['name']}; conservar pagos hechos',
                        (c) => c.removeInvestment(inv['id'] as String)),
                    child: const Text('Eliminar')),
                TextButton(
                    onPressed: () async {
                      final result = await form('Mover cuotas', [
                        const InputSpec('months', 'Meses hacia adelante',
                            initial: '1', numeric: true)
                      ]);
                      if (!mounted || result == null) return;
                      await review(
                          data,
                          'Mover cuotas de ${inv['name']}',
                          (c) => c.shiftInvestment(inv['id'] as String,
                              int.tryParse(result['months']!) ?? 0, now));
                    },
                    child: const Text('Mover cuotas'))
              ]),
              ExpansionTile(
                  title: const Text('Cuotas y proyección'),
                  children: List.generate(rows.length, (i) {
                    final row = rows[i];
                    return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${row['m']} · ${cop(number(row['amt']))} · ${row['paid'] == true ? 'Pagado' : 'Pendiente'}'),
                              Text(
                                  'Aportado acumulado: ${cop(number(path[i]['contributed']))} · estimado: ${cop(number(path[i]['value']))}'),
                              TextButton(
                                  onPressed: () => review(
                                      data,
                                      '${row['paid'] == true ? 'Deshacer' : 'Pagar'} inversión de ${row['m']}',
                                      (c) => c.commands
                                          .togglePayment(row['id'] as String)),
                                  child: Text(row['paid'] == true
                                      ? 'Deshacer'
                                      : 'Pagar'))
                            ]));
                  })),
            ])));
  }

  Widget savingCard(DashboardSnapshot data, Map saving) {
    final balance = savingBalance(data.document.fields, saving);
    final members = records(saving, 'members');
    final editable =
        members.where((p) => canEditContribution(saving, p)).toList();
    final rows = records(data.document.fields, 'contrib').where(
        (c) => c['savingId'] == saving['id'] && c['m'] == monthKey(month));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(saving['name'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  '${saving['bank'] ?? ''} · ${saving['isOwner'] == true ? 'Ahorro propio' : 'Compartido contigo'}'),
              Text('Ahorrado: ${cop(balance)}'),
              Text(savingEta(data.document.fields, saving, now)),
              const Text(
                  'Los fondos vinculados a cuentas no se suman otra vez al saldo neto.'),
              Wrap(spacing: 8, children: [
                if (saving['isOwner'] == true) ...[
                  TextButton(
                      onPressed: () => savingForm(data, saving),
                      child: const Text('Editar ahorro')),
                  TextButton(
                      onPressed: () => memberForm(data, saving),
                      child: const Text('Agregar persona')),
                  TextButton(
                      onPressed: () => review(
                          data,
                          'Eliminar ${saving['name']} para todos; no cambia saldos de cuentas',
                          (c) => c.removeSaving(saving['id'] as String)),
                      child: const Text('Eliminar ahorro'))
                ],
                TextButton(
                    onPressed: () async {
                      final own = members.where((p) => p['mine'] == true);
                      final result = await form('Vincular tus cuentas', [
                        account(data, 'fund', 'Cuenta donde está el ahorro',
                            saving['acc'] as String?),
                        account(data, 'source', 'Cuenta de origen',
                            own.isEmpty ? null : own.first['acc'] as String?)
                      ]);
                      if (!mounted || result == null) return;
                      await review(
                          data,
                          'Vincular cuentas sin volver a sumar aportes pasados',
                          (c) => c.linkSavingAccounts(
                              saving['id'] as String,
                              nullable(result['fund']),
                              nullable(result['source'])));
                    },
                    child: const Text('Vincular cuentas'))
              ]),
              ExpansionTile(
                  title: const Text('Personas y aportes mensuales'),
                  children: members
                      .map((p) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${p['mine'] == true ? 'Tú' : p['name']} · ${cop(number(p['monthly']))} al mes'),
                                if (saving['isOwner'] == true)
                                  Wrap(children: [
                                    TextButton(
                                        onPressed: () =>
                                            memberForm(data, saving, p),
                                        child: const Text('Editar persona')),
                                    if (p['mine'] != true)
                                      TextButton(
                                          onPressed: () => review(
                                              data,
                                              'Quitar a ${p['name']} del ahorro compartido',
                                              (c) => c.removeMember(
                                                  saving['id'] as String,
                                                  p['id'] as String,
                                                  now)),
                                          child: const Text('Quitar persona'))
                                  ])
                              ])))
                      .toList()),
              Text('Aportes de ${monthLabel(month)}'),
              if (rows.isEmpty)
                const Text('No hay aportes registrados este mes.'),
              ...rows.map((row) {
                final matches =
                    members.where((p) => p['id'] == row['memberId']);
                final p = matches.isEmpty ? null : matches.first;
                final allowed = canEditContribution(saving, p);
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${p?['name'] ?? 'Persona anterior'} · ${cop(number(row['amt']))} · ${row['done'] == true ? 'Realizado' : 'Pendiente'}'),
                          if (allowed)
                            Wrap(children: [
                              TextButton(
                                  onPressed: () => review(
                                          data,
                                          row['extra'] == true
                                              ? 'Quitar movimiento extra'
                                              : '${row['done'] == true ? 'Deshacer' : 'Registrar'} aporte de ${p?['name']}',
                                          (c) {
                                        if (row['extra'] == true) {
                                          c.removeExtra(row['id'] as String);
                                        } else {
                                          c.setContribution(row['id'] as String,
                                              row['done'] != true);
                                        }
                                      }),
                                  child: Text(row['extra'] == true
                                      ? 'Quitar extra'
                                      : row['done'] == true
                                          ? 'Deshacer'
                                          : 'Aportó')),
                              if (row['done'] != true && row['extra'] != true)
                                TextButton(
                                    onPressed: () async {
                                      final result = await form(
                                          'Monto del aporte', [
                                        InputSpec('amount', 'COP',
                                            initial: '${row['amt']}',
                                            numeric: true)
                                      ]);
                                      if (!mounted || result == null) return;
                                      await review(
                                          data,
                                          'Cambiar aporte de ${p?['name']}',
                                          (c) => c.setContributionAmount(
                                              row['id'] as String,
                                              amount(result['amount'])));
                                    },
                                    child: const Text('Cambiar monto'))
                            ])
                        ]));
              }),
              if (editable.isNotEmpty)
                TextButton(
                    onPressed: () async {
                      final result = await form('Aporte extra o retiro', [
                        const InputSpec('kind', 'Movimiento',
                            initial: 'in',
                            options: {'in': 'Aporte extra', 'out': 'Retiro'}),
                        InputSpec('member', 'Persona',
                            initial: editable.first['id'] as String,
                            options: {
                              for (final p in editable)
                                p['id'] as String: p['name'] as String
                            }),
                        const InputSpec('amount', 'Monto COP positivo',
                            numeric: true)
                      ]);
                      if (!mounted || result == null) return;
                      await review(
                          data,
                          '${result['kind'] == 'out' ? 'Retirar' : 'Aportar extra'} en ${saving['name']}',
                          (c) => c.extraContribution(
                              saving['id'] as String,
                              result['member']!,
                              monthKey(month),
                              amount(result['amount']),
                              result['kind'] == 'out'));
                    },
                    child: const Text('Aporte extra / retiro')),
              ExpansionTile(
                  title: const Text('Proyección de ahorro · 12 meses'),
                  children: List.generate(12, (i) {
                    final m = DateTime(month.year, month.month + i);
                    return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                            '${monthLabel(m)}: ${cop(savingAt(data.document.fields, saving, monthKey(m), now))} estimados'));
                  })),
            ])));
  }

  Widget loaded(DashboardSnapshot data) {
    try {
      final items = records(
          data.document.fields, investments ? 'investments' : 'savings');
      return ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('Ahorros'),
              selected: !investments,
              onSelected: (_) => setState(() => investments = false)),
          ChoiceChip(
              label: const Text('Inversiones'),
              selected: investments,
              onSelected: (_) => setState(() => investments = true))
        ]),
        if (!investments)
          Row(children: [
            IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
                child: Text(monthLabel(month), textAlign: TextAlign.center)),
            IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right))
          ]),
        FilledButton.icon(
            onPressed: () =>
                investments ? investmentForm(data) : savingForm(data),
            icon: const Icon(Icons.add),
            label: Text(investments ? 'Crear inversión' : 'Crear ahorro')),
        if (!investments)
          Wrap(children: [
            TextButton(
                onPressed: () => review(
                    data,
                    'Generar próximos 12 meses de aportes',
                    (c) => c.extendSavings(now)),
                child: const Text('Extender aportes')),
            TextButton(
                onPressed: () => review(
                    data,
                    'Revisar aportes compartidos y sus efectos en cuentas',
                    (c) => c.reconcileShared()),
                child: const Text('Actualizar aportes ajenos en cuentas'))
          ]),
        if (items.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aún no hay registros en esta sección.')),
        ...items.map((item) =>
            investments ? investmentCard(data, item) : savingCard(data, item)),
      ]);
    } catch (_) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No se pudieron interpretar estos datos. Revisa la información en la web y actualiza.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Ahorros e inversiones'), actions: [
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
