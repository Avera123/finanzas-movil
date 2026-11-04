import 'dart:math' as math;
import '../../movements/domain/finance_commands.dart';

double number(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Importe o tasa inválidos.');
  }
  return value.toDouble();
}

List<Map> records(Map data, String key) =>
    (data[key] as List? ?? []).cast<Map>();
double sumRows(Iterable<Map> rows, [String key = 'amt']) =>
    rows.fold(0.0, (sum, row) => sum + number(row[key]));
bool debtRow(Map row) => row['debtId'] != null || row['cat'] == 'Deuda';
bool livingRow(Map row) => !debtRow(row) && row['investId'] == null;
double incomeFor(Map data, String month) =>
    number((data['inc'] as Map?)?[month] ??
        number(data['usd']) * number(data['rate']));
double baseLiving(Map data, String now) {
  if (data['living'] != null) return number(data['living']);
  final rows = records(data, 'exp')
      .where((e) => (e['m'] as String).compareTo(now) < 0 && livingRow(e));
  final months = rows.map((e) => e['m'] as String).toSet().toList()..sort();
  final recent = months.skip(math.max(0, months.length - 3)).toSet();
  return recent.isEmpty
      ? 0
      : sumRows(rows.where((e) => recent.contains(e['m']))) / recent.length;
}

double myContribution(Map data, String month, String now) {
  final mine = <String>{};
  for (final fund in records(data, 'savings')) {
    for (final member in records(fund, 'members')) {
      if (member['mine'] == true) mine.add('${fund['id']}/${member['id']}');
    }
  }
  final rows = records(data, 'contrib')
      .where((c) =>
          c['m'] == month && mine.contains('${c['savingId']}/${c['memberId']}'))
      .toList();
  if (rows.isNotEmpty || month.compareTo(now) <= 0) return sumRows(rows);
  return records(data, 'savings').fold(0.0, (total, fund) {
    if (month.compareTo(fund['startM'] as String) < 0 ||
        (fund['endM'] != null && month.compareTo(fund['endM'] as String) > 0)) {
      return total;
    }
    return total +
        sumRows(records(fund, 'members').where((p) => p['mine'] == true),
            'monthly');
  });
}

double freeIncome(Map data, String month, String now, [String? exceptDebt]) {
  final rows = records(data, 'exp').where((e) => e['m'] == month);
  final commitments = rows.where((e) =>
      (debtRow(e) || e['investId'] != null) &&
      !(e['debtId'] != null && e['debtId'] == exceptDebt && e['paid'] != true));
  return incomeFor(data, month) -
      math.max(baseLiving(data, now), sumRows(rows.where(livingRow))) -
      sumRows(commitments) -
      myContribution(data, month, now);
}

int paymentForMonths(double balance, double rate, int months) {
  if (balance <= 0 || rate < 0 || months < 1 || months > 600) {
    throw const FormatException('Revisa monto, tasa y plazo (1 a 600).');
  }
  final r = rate / 100;
  return (r == 0
          ? balance / months
          : balance * r / (1 - math.pow(1 + r, -months)) / (1 + r))
      .ceil();
}

double? impliedMonthlyRate(double total, double payment, int months) {
  if (payment * months < total) return null;
  double lo = 0, hi = 1;
  for (var i = 0; i < 80; i++) {
    final mid = (lo + hi) / 2;
    final pv = mid == 0
        ? payment * months
        : payment * (1 - math.pow(1 + mid, -months)) / mid * (1 + mid);
    if (pv >= total) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo * 100;
}

class DebtSchedule {
  const DebtSchedule(this.ok, this.rows, this.interest);
  final bool ok;
  final List<Map<String, dynamic>> rows;
  final double interest;
}

DebtSchedule debtSchedule(Map data, Map debt, String now) {
  final paid = <String, double>{};
  for (final row in records(data, 'exp')) {
    if (row['debtId'] == debt['id'] && row['paid'] == true) {
      paid.update(row['m'] as String, (v) => v + number(row['amt']),
          ifAbsent: () => number(row['amt']));
    }
  }
  final firsts = [
    debt['startM'] as String,
    now,
    if (debt['resumeM'] != null) debt['resumeM'] as String
  ]..sort();
  final first = firsts.last;
  final rows = <Map<String, dynamic>>[];
  if (debt['mode'] == 'open') {
    final end = debt['endM'] as String? ?? addMonth(now, 11);
    for (var month = first;
        month.compareTo(end) <= 0;
        month = addMonth(month, 1)) {
      if ((paid[month] ?? 0) == 0) {
        rows.add({'m': month, 'amt': number(debt['cuota'])});
      }
    }
    return DebtSchedule(true, rows, 0);
  }
  var balance = number(debt['total']), interest = 0.0;
  final rate = number(debt['rate'] ?? 0) / 100;
  var month = debt['startM'] as String;
  for (var i = 0; i < 600; i++, month = addMonth(month, 1)) {
    if (month.compareTo(debt['startM'] as String) > 0) {
      final charge = balance * rate;
      balance += charge;
      interest += charge;
    }
    balance -= paid[month] ?? 0;
    if (balance < 1) return DebtSchedule(true, rows, interest);
    if (month.compareTo(first) < 0) continue;
    final want = debt['mode'] == 'fast'
        ? freeIncome(data, month, now, debt['id'] as String)
        : number(debt['cuota']) - (paid[month] ?? 0);
    final amount = math.min(math.max(want, 0), balance).ceil();
    if (amount > 0) {
      rows.add({'m': month, 'amt': amount});
      balance -= amount;
    }
    if (balance < 1) return DebtSchedule(true, rows, interest);
  }
  return const DebtSchedule(false, [], 0);
}

double debtBalance(Map data, Map debt, String month, String now) {
  if (month.compareTo(debt['startM'] as String) < 0) return 0;
  var balance = number(debt['total']);
  final rate = number(debt['rate'] ?? 0) / 100;
  for (var m = debt['startM'] as String;
      m.compareTo(month) <= 0;
      m = addMonth(m, 1)) {
    if (m.compareTo(debt['startM'] as String) > 0) balance += balance * rate;
    balance = math.max(
        0,
        balance -
            sumRows(records(data, 'exp').where((e) =>
                e['debtId'] == debt['id'] &&
                e['m'] == m &&
                (e['paid'] == true || m.compareTo(now) >= 0))));
  }
  return balance;
}

DateTime civilDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Usa fecha AAAA-MM-DD.');
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw const FormatException('Fecha inválida.');
  }
  return date;
}

String civilToday(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
double loanBalance(Map data, Map loan) => math.max(
    0,
    number(loan['total']) -
        sumRows(
            records(data, 'loanPay').where((p) => p['loanId'] == loan['id'])));
String loanDueLabel(Map data, Map loan, String today) {
  if (loanBalance(data, loan) < 1) return 'Pagado';
  final days =
      civilDate(loan['dueOn'] as String).difference(civilDate(today)).inDays;
  return days < 0
      ? 'Vencido hace ${-days} días'
      : days == 0
          ? 'Vence hoy'
          : 'Vence en $days días';
}
