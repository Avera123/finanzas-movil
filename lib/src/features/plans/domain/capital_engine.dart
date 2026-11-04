import 'dart:math' as math;
import '../../movements/domain/finance_commands.dart';
import 'plan_engine.dart';

double monthlyYield(double annual) =>
    annual > 0 ? math.pow(1 + annual / 100, 1 / 12).toDouble() - 1 : 0;
int paymentForGoal(double target, int months, double annual) {
  if (target <= 0 || months < 1 || months > 600 || annual < 0) {
    throw const FormatException('Revisa meta, plazo y rendimiento.');
  }
  final r = monthlyYield(annual);
  return (r == 0
          ? target / months
          : target * r / ((math.pow(1 + r, months) - 1) * (1 + r)))
      .ceil();
}

double investmentAmount(Map data, Map investment, String month) =>
    investment['mode'] == 'percent'
        ? (incomeFor(data, month) * number(investment['value']) / 100 + .5)
            .floorToDouble()
        : number(investment['value']);
List<Map<String, dynamic>> investmentPlan(
    Map data, Map investment, String now) {
  final paid = records(data, 'exp')
      .where((e) => e['investId'] == investment['id'] && e['paid'] == true)
      .toList();
  final taken = paid.map((e) => e['m']).toSet();
  final starts = [
    investment['startM'] as String,
    now,
    if (investment['resumeM'] != null) investment['resumeM'] as String
  ]..sort();
  final rows = <Map<String, dynamic>>[];
  for (var month = starts.last;
      rows.length < number(investment['months']) - paid.length;
      month = addMonth(month, 1)) {
    if (!taken.contains(month)) {
      rows.add({'m': month, 'amt': investmentAmount(data, investment, month)});
    }
  }
  return rows;
}

List<Map<String, dynamic>> investmentPath(Map data, Map investment) {
  final rows = records(data, 'exp')
      .where((e) => e['investId'] == investment['id'])
      .toList()
    ..sort((a, b) => (a['m'] as String).compareTo(b['m'] as String));
  final result = <Map<String, dynamic>>[];
  final r = monthlyYield(number(investment['rate'] ?? 0));
  var value = 0.0, contributed = 0.0;
  for (final row in rows) {
    contributed += number(row['amt']);
    value = (value + number(row['amt'])) * (1 + r);
    result.add({
      'm': row['m'],
      'contributed': contributed,
      'value': (value + .5).floor()
    });
  }
  return result;
}

bool canEditContribution(Map fund, Map? member) =>
    member != null &&
    (member['mine'] == true ||
        (fund['isOwner'] == true &&
            (member['email'] == null || member['email'] == '')));
double savingBalance(Map data, Map fund) =>
    number(fund['start']) +
    sumRows(records(data, 'contrib')
        .where((c) => c['savingId'] == fund['id'] && c['done'] == true));
double savingAt(Map data, Map fund, String month, String now) {
  if (month.compareTo(fund['startM'] as String) < 0) return 0;
  var balance = number(fund['start']) +
      sumRows(records(data, 'contrib').where((c) =>
          c['savingId'] == fund['id'] &&
          (c['m'] as String).compareTo(month) <= 0 &&
          (c['done'] == true || (c['m'] as String).compareTo(now) >= 0)));
  final last = addMonth(now, 11);
  for (var m = addMonth(last, 1); m.compareTo(month) <= 0; m = addMonth(m, 1)) {
    if (m.compareTo(fund['startM'] as String) >= 0 &&
        (fund['endM'] == null || m.compareTo(fund['endM'] as String) <= 0)) {
      balance += sumRows(records(fund, 'members'), 'monthly');
    }
  }
  return balance;
}

String savingEta(Map data, Map fund, String now) {
  final target = fund['target'];
  if (target is! num || target <= 0) return 'Sin meta';
  final missing = target - savingBalance(data, fund);
  if (missing <= 0) return 'Meta alcanzada';
  final monthly = sumRows(records(fund, 'members'), 'monthly');
  if (monthly <= 0) return 'Sin aportes mensuales';
  final start = (fund['startM'] as String).compareTo(now) > 0
      ? fund['startM'] as String
      : now;
  final end = addMonth(start, (missing / monthly).ceil() - 1);
  if (fund['endM'] != null && end.compareTo(fund['endM'] as String) > 0) {
    return 'No se alcanza antes del mes final';
  }
  return 'Meta estimada en $end';
}
