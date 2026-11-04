import 'dart:math';
import '../../../core/models/finance_draft.dart';

class FinanceCommands {
  FinanceCommands(this.draft);
  final FinanceDraft draft;
  Map<String, dynamic> get data => draft.fields;
  List get expenses => data['exp'] as List;
  List get accounts => data['acc'] as List;
  String newId() =>
      List.generate(16, (_) => Random.secure().nextInt(16).toRadixString(16))
          .join();
  Map expense(String id) =>
      expenses.cast<Map>().firstWhere((e) => e['id'] == id);
  void togglePayment(String id) {
    final row = expense(id);
    final wasPaid = row['paid'] == true;
    final amount = (row['amt'] as num).toDouble();
    final matches = accounts.cast<Map>().where((a) => a['id'] == row['acc']);
    if (matches.isNotEmpty) {
      final account = matches.first;
      account['bal'] = (account['bal'] as num) +
          (account['type'] == 'Crédito' ? 1 : -1) * amount * (wasPaid ? -1 : 1);
    }
    row['paid'] = !wasPaid;
  }

  void assignAccount(String id, String? account) {
    final row = expense(id);
    if (row['paid'] == true) {
      throw const FormatException('Deshaz el pago antes de cambiar la cuenta.');
    }
    if (account != null &&
        !accounts.cast<Map>().any((a) => a['id'] == account)) {
      throw const FormatException('Cuenta inexistente.');
    }
    row['acc'] = account;
  }

  void deleteExpense(String id) {
    final row = expense(id);
    if (row['debtId'] != null || row['investId'] != null) {
      throw const FormatException('Gestiona esta cuota desde su plan.');
    }
    if (row['paid'] == true) togglePayment(id);
    expenses.remove(row);
  }

  void addExpense(
      {required String name,
      required double amount,
      required String month,
      required String category,
      required String method,
      String? account,
      int repeat = 1}) {
    if (name.trim().isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        repeat < 1 ||
        repeat > 600) {
      throw const FormatException(
          'Revisa nombre, monto y número de meses (1 a 600).');
    }
    final series = repeat > 1 ? newId() : null;
    for (var i = 0; i < repeat; i++) {
      expenses.add({
        'id': newId(),
        'm': addMonth(month, i),
        'name': name.trim(),
        'cat': category,
        'amt': amount,
        'meth': method,
        'acc': account,
        'paid': false,
        if (series != null) 'seriesId': series
      });
    }
  }

  void move(String id, String target, {bool series = false}) {
    final row = expense(id);
    if (row['paid'] == true ||
        row['debtId'] != null ||
        row['investId'] != null) {
      throw const FormatException(
          'Solo puedes mover gastos pendientes sin plan vinculado aquí.');
    }
    addMonth(target, 0); // Validate date before modifying any row.
    if (row['seriesId'] != null) {
      if (!series) {
        throw const FormatException('Esta cuota requiere mover su serie.');
      }
      final from = row['m'] as String;
      final shift = monthNumber(target) - monthNumber(from);
      if (shift < 1) {
        throw const FormatException(
            'Las series solo se mueven hacia adelante.');
      }
      for (final item in expenses.cast<Map>()) {
        if (item['seriesId'] == row['seriesId'] &&
            item['paid'] != true &&
            (item['m'] as String).compareTo(from) >= 0) {
          item['m'] = addMonth(item['m'] as String, shift);
        }
      }
    } else {
      row['m'] = target;
    }
  }

  void addAccount(String name, String type, double balance) {
    if (name.trim().isEmpty || type.trim().isEmpty || !balance.isFinite) {
      throw const FormatException('Revisa nombre, tipo y saldo de la cuenta.');
    }
    accounts.add(
        {'id': newId(), 'name': name.trim(), 'type': type, 'bal': balance});
  }

  void setAccountBalance(String id, double value) {
    if (!value.isFinite) throw const FormatException('Saldo inválido.');
    accounts.cast<Map>().firstWhere((a) => a['id'] == id)['bal'] = value;
  }

  void depositUsd(String id, double usd) {
    final rate = data['rate'];
    if (!usd.isFinite || usd <= 0 || rate is! num || rate <= 0) {
      throw const FormatException(
          'Revisa el monto USD y configura la tasa en la web.');
    }
    final account = accounts.cast<Map>().firstWhere((a) => a['id'] == id);
    account['bal'] = (account['bal'] as num) +
        (account['type'] == 'Crédito' ? -1 : 1) * usd * rate;
  }

  void addOption(String key, String value) {
    if (key != 'cats' && key != 'meths') {
      throw const FormatException('Lista inválida.');
    }
    final rows = data[key] as List;
    value = value.trim();
    if (value.isEmpty || rows.contains(value)) {
      throw const FormatException('Escribe un nombre nuevo.');
    }
    rows.add(value);
  }

  void removeOption(String key, String value) {
    if (key != 'cats' && key != 'meths') {
      throw const FormatException('Lista inválida.');
    }
    final field = key == 'cats' ? 'cat' : 'meth';
    if (expenses.cast<Map>().any((e) => e[field] == value)) {
      throw const FormatException('Hay gastos que usan esta opción.');
    }
    (data[key] as List).remove(value);
  }

  void setIncome(String month, double? value) {
    addMonth(month, 0);
    if (value != null && (!value.isFinite || value < 0)) {
      throw const FormatException(
          'El ingreso debe ser un número positivo o cero.');
    }
    data['inc'] ??= <String, dynamic>{};
    final income = data['inc'] as Map;
    if (value == null) {
      income.remove(month);
    } else {
      income[month] = value;
    }
    syncPercentInvestments();
  }

  void syncPercentInvestments() {
    for (final inv in (data['investments'] as List? ?? []).cast<Map>()) {
      if (inv['mode'] != 'percent') continue;
      for (final row in expenses.cast<Map>()) {
        if (row['investId'] != inv['id'] || row['paid'] == true) continue;
        final income = (data['inc'] as Map?)?[row['m']] ??
            (data['usd'] as num) * (data['rate'] as num);
        // JS Math.round: floor(x + .5); all valid investment values are nonnegative.
        row['amt'] =
            ((income as num) * (inv['value'] as num) / 100 + .5).floor();
      }
    }
  }
}

int monthNumber(String month) {
  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
    throw const FormatException('El mes debe tener formato AAAA-MM.');
  }
  final parts = month.split('-').map(int.parse).toList();
  return parts[0] * 12 + parts[1] - 1;
}

String addMonth(String month, int offset) {
  final index = monthNumber(month) + offset;
  if (index < 12 || index >= 120000) {
    throw const FormatException('Mes fuera de rango.');
  }
  return '${(index ~/ 12).toString().padLeft(4, '0')}-${(index % 12 + 1).toString().padLeft(2, '0')}';
}
