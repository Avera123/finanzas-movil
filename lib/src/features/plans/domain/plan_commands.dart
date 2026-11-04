import '../../movements/domain/finance_commands.dart';
import 'plan_engine.dart';

class PlanCommands {
  PlanCommands(this.commands);
  final FinanceCommands commands;
  Map<String, dynamic> get data => commands.data;
  void setLiving(double? value) {
    if (value != null && (!value.isFinite || value < 0)) {
      throw const FormatException('El presupuesto debe ser positivo o cero.');
    }
    data['living'] = value;
  }

  void convertOpen(String name, String now) {
    final matching = records(data, 'exp')
        .where((e) =>
            e['name'] == name &&
            e['paid'] != true &&
            e['debtId'] == null &&
            e['investId'] == null &&
            (e['m'] as String).compareTo(now) >= 0)
        .toList()
      ..sort((a, b) => (a['m'] as String).compareTo(b['m'] as String));
    if (matching.isEmpty) {
      throw const FormatException('No hay cuotas pendientes para convertir.');
    }
    final id = commands.newId();
    data['debts'] ??= <Map>[];
    (data['debts'] as List).add({
      'id': id,
      'name': name,
      'total': 0,
      'rate': 0,
      'cuota': matching.first['amt'],
      'startM': now,
      'acc': matching.first['acc'],
      'mode': 'open',
      'endM': null
    });
    final cats = data['cats'] as List;
    if (!cats.contains('Deuda')) cats.add('Deuda');
    for (final row in records(data, 'exp')) {
      if (row['name'] == name &&
          row['debtId'] == null &&
          row['investId'] == null) {
        row['debtId'] = id;
        row['cat'] = 'Deuda';
      }
    }
    extendOpen(now);
  }

  void adjustAccount(String? id, double delta) {
    final found = records(data, 'acc').where((a) => a['id'] == id);
    if (found.isEmpty) return;
    final account = found.first;
    account['bal'] = number(account['bal']) +
        (account['type'] == 'Crédito' ? -delta : delta);
  }

  void applyDebt(Map debt, String now) {
    final plan = debtSchedule(data, debt, now);
    if (!plan.ok) {
      throw const FormatException(
          'La cuota o el presupuesto no alcanzan para pagar en 600 meses.');
    }
    final categories = data['cats'] as List;
    if (!categories.contains('Deuda')) categories.add('Deuda');
    data['exp'] = records(data, 'exp')
        .where((e) => !(e['debtId'] == debt['id'] && e['paid'] != true))
        .toList();
    final methods = data['meths'] as List;
    if (methods.isEmpty) {
      throw const FormatException('Configura un tipo de pago primero.');
    }
    for (final row in plan.rows) {
      (data['exp'] as List).add({
        'id': commands.newId(),
        ...row,
        'name': debt['name'],
        'cat': 'Deuda',
        'meth':
            methods.contains('Transferencia') ? 'Transferencia' : methods.first,
        'acc': debt['acc'],
        'paid': false,
        'debtId': debt['id']
      });
    }
  }

  void saveDebt(
      {String? id,
      required String name,
      required String mode,
      required double total,
      required double rate,
      required double value,
      required int count,
      required String start,
      String? end,
      String? account,
      String? replaceName,
      required String now}) {
    monthNumber(start);
    if (end != null) {
      monthNumber(end);
      if (end.compareTo(start) < 0) {
        throw const FormatException('El fin no puede ser anterior al inicio.');
      }
    }
    if (name.trim().isEmpty ||
        !['cuota', 'known', 'months', 'fast', 'open'].contains(mode) ||
        !rate.isFinite ||
        rate < 0 ||
        !total.isFinite ||
        !value.isFinite ||
        (mode != 'open' && total <= 0) ||
        (mode != 'fast' && value <= 0)) {
      throw const FormatException('Revisa nombre, monto, interés y cuota.');
    }
    if ((mode == 'known' || mode == 'months') && (count < 1 || count > 600)) {
      throw const FormatException('El plazo debe estar entre 1 y 600 meses.');
    }
    final effectiveRate = mode == 'open'
        ? 0.0
        : mode == 'known'
            ? impliedMonthlyRate(total, value, count)
            : rate;
    if (effectiveRate == null) {
      throw const FormatException(
          'Las cuotas no alcanzan a pagar el monto prestado.');
    }
    data['debts'] ??= <Map>[];
    final existing = id == null
        ? null
        : records(data, 'debts').firstWhere((d) => d['id'] == id);
    final debt = existing ?? <String, dynamic>{'id': commands.newId()};
    if (existing != null && existing['startM'] != start) {
      throw const FormatException('Conserva el mes inicial de la deuda.');
    }
    debt.addAll(<String, dynamic>{
      'name': name.trim(),
      'total': mode == 'open' ? 0 : total,
      'rate': effectiveRate,
      'startM': start,
      'endM': mode == 'open' ? end : null,
      'acc': account,
      'mode': mode == 'fast'
          ? 'fast'
          : mode == 'open'
              ? 'open'
              : 'fixed',
      'cuota': mode == 'fast'
          ? 0
          : mode == 'months'
              ? paymentForMonths(total, effectiveRate, count)
              : value
    });
    if (existing == null) (data['debts'] as List).add(debt);
    if (replaceName != null && replaceName.isNotEmpty && existing == null) {
      data['exp'] = records(data, 'exp')
          .where((e) => !(e['name'] == replaceName &&
              e['paid'] != true &&
              e['debtId'] == null &&
              (e['m'] as String).compareTo(now) >= 0))
          .toList();
    }
    applyDebt(debt, now);
  }

  Map debtById(String id) =>
      records(data, 'debts').firstWhere((d) => d['id'] == id);
  void removeDebt(String id) {
    data['exp'] = records(data, 'exp')
        .where((e) => !(e['debtId'] == id && e['paid'] != true))
        .toList();
    for (final row in records(data, 'exp')) {
      if (row['debtId'] == id) row['debtId'] = null;
    }
    data['debts'] = records(data, 'debts').where((d) => d['id'] != id).toList();
  }

  void extraPayment(String id, double amount, String now) {
    final debt = debtById(id);
    final currentMonth = now.compareTo(debt['startM'] as String) < 0
        ? debt['startM'] as String
        : now;
    final balance = debtBalance(data, debt, currentMonth, '9999-12');
    if (debt['mode'] == 'open' ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > balance) {
      throw const FormatException(
          'El abono debe ser positivo y no superar el saldo conocido.');
    }
    final methods = data['meths'] as List;
    if (methods.isEmpty) {
      throw const FormatException('Configura un tipo de pago.');
    }
    final rowId = commands.newId();
    (data['exp'] as List).add({
      'id': rowId,
      'm': now,
      'name': 'Abono: ${debt['name']}',
      'cat': 'Deuda',
      'amt': amount,
      'meth':
          methods.contains('Transferencia') ? 'Transferencia' : methods.first,
      'acc': debt['acc'],
      'paid': false,
      'debtId': id
    });
    commands.togglePayment(rowId);
    applyDebt(debt, now);
  }

  void fastest(String id, String now) {
    final debt = debtById(id);
    debt['mode'] = 'fast';
    applyDebt(debt, now);
  }

  void extendOpen(String now) {
    for (final debt
        in records(data, 'debts').where((d) => d['mode'] == 'open')) {
      for (final row in debtSchedule(data, debt, now).rows) {
        if (records(data, 'exp')
            .any((e) => e['debtId'] == debt['id'] && e['m'] == row['m'])) {
          continue;
        }
        final methods = data['meths'] as List;
        (data['exp'] as List).add({
          'id': commands.newId(),
          ...row,
          'name': debt['name'],
          'cat': 'Deuda',
          'meth': methods.contains('Transferencia')
              ? 'Transferencia'
              : methods.first,
          'acc': debt['acc'],
          'paid': false,
          'debtId': debt['id']
        });
      }
    }
  }

  void shiftDebt(String id, int months, String now) {
    if (months < 1 || months > 600) {
      throw const FormatException('Mueve entre 1 y 600 meses hacia adelante.');
    }
    final debt = debtById(id);
    final pending = records(data, 'exp')
        .where((e) => e['debtId'] == id && e['paid'] != true)
        .toList()
      ..sort((a, b) => (a['m'] as String).compareTo(b['m'] as String));
    final first =
        pending.isEmpty || (pending.first['m'] as String).compareTo(now) < 0
            ? now
            : pending.first['m'] as String;
    final resume = addMonth(first, months);
    debt['resumeM'] = resume;
    if (debt['mode'] != 'open') {
      applyDebt(debt, now);
      return;
    }
    if (debt['endM'] != null) {
      debt['endM'] = addMonth(debt['endM'] as String, months);
    }
    for (var i = 0; i < pending.length; i++) {
      pending[i]['m'] = addMonth(resume, i);
    }
    extendOpen(now);
  }

  void setOpenAmount(String id, double amount) {
    final row = commands.expense(id);
    if (row['paid'] == true ||
        debtById(row['debtId'] as String)['mode'] != 'open' ||
        !amount.isFinite ||
        amount < 0) {
      throw const FormatException(
          'Solo puedes ajustar una cuota abierta pendiente.');
    }
    row['amt'] = amount;
  }

  void createLoan(String person, double total, String lentOn, String dueOn,
      String? account, String note) {
    if (person.trim().isEmpty ||
        !total.isFinite ||
        total <= 0 ||
        civilDate(dueOn).isBefore(civilDate(lentOn))) {
      throw const FormatException(
          'Revisa persona, monto y fechas del préstamo.');
    }
    data['loans'] ??= <Map>[];
    (data['loans'] as List).add({
      'id': commands.newId(),
      'person': person.trim(),
      'total': total,
      'lentOn': lentOn,
      'dueOn': dueOn,
      'acc': account,
      'note': note.trim().isEmpty ? null : note.trim()
    });
    if (account != null) adjustAccount(account, -total);
  }

  void receiveLoan(String id, double amount, String on, String? account) {
    civilDate(on);
    final loan = records(data, 'loans').firstWhere((l) => l['id'] == id);
    if (!amount.isFinite || amount <= 0 || amount > loanBalance(data, loan)) {
      throw const FormatException(
          'El cobro debe ser positivo y no superar lo pendiente.');
    }
    data['loanPay'] ??= <Map>[];
    (data['loanPay'] as List).add({
      'id': commands.newId(),
      'loanId': id,
      'on': on,
      'amt': amount,
      'acc': account
    });
    if (account != null) adjustAccount(account, amount);
  }

  void undoLoanReceipt(String id) {
    final row = records(data, 'loanPay').firstWhere((p) => p['id'] == id);
    adjustAccount(row['acc'] as String?, -number(row['amt']));
    data['loanPay'] =
        records(data, 'loanPay').where((p) => p['id'] != id).toList();
  }

  void removeLoan(String id) {
    final loan = records(data, 'loans').firstWhere((l) => l['id'] == id);
    adjustAccount(loan['acc'] as String?, number(loan['total']));
    for (final payment
        in records(data, 'loanPay').where((p) => p['loanId'] == id).toList()) {
      undoLoanReceipt(payment['id'] as String);
    }
    data['loans'] = records(data, 'loans').where((l) => l['id'] != id).toList();
  }

  void changeLoanDate(String id, String on) {
    civilDate(on);
    records(data, 'loans').firstWhere((l) => l['id'] == id)['dueOn'] = on;
  }
}
