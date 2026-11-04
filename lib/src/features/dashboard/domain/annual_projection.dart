import 'dart:math' as math;
import '../../plans/domain/plan_engine.dart';
import '../../plans/domain/capital_engine.dart';

/// Monthly flows and closing stocks, matching the verified web monthly().
Map<String, double> annualMonth(Map data, String month, String now) {
  final rows = records(data, 'exp').where((e) => e['m'] == month);
  final debtPay = sumRows(rows.where(debtRow));
  final invest = sumRows(rows.where((e) => e['investId'] != null));
  final recorded = sumRows(rows) - debtPay - invest;
  final living = month.compareTo(now) > 0
      ? math.max(recorded, baseLiving(data, now))
      : recorded;
  final income = incomeFor(data, month);
  final savings = myContribution(data, month, now);
  final received = sumRows(records(data, 'loanPay')
      .where((p) => (p['on'] as String).substring(0, 7) == month));
  final loans = records(data, 'loans');
  final loanIn = received +
      (month.compareTo(now) < 0
          ? 0.0
          : loans
              .where((l) => (l['dueOn'] as String).substring(0, 7) == month)
              .fold(0.0, (sum, l) => sum + loanBalance(data, l)));
  final loanOut = loans
      .where((l) =>
          l['acc'] != null &&
          l['acc'] != '' &&
          (l['lentOn'] as String).substring(0, 7) == month)
      .fold(0.0, (sum, l) => sum + number(l['total']));
  final receivable = loans.fold(0.0, (sum, l) {
    if ((l['lentOn'] as String).substring(0, 7).compareTo(month) > 0) {
      return sum;
    }
    final due = (l['dueOn'] as String).substring(0, 7);
    if (month.compareTo(now) >= 0 &&
        due.compareTo(now) >= 0 &&
        due.compareTo(month) <= 0) {
      return sum;
    }
    return sum +
        math.max(
            0,
            number(l['total']) -
                sumRows(records(data, 'loanPay').where((p) =>
                    p['loanId'] == l['id'] &&
                    (p['on'] as String).substring(0, 7).compareTo(month) <=
                        0)));
  });
  final total = living + debtPay + savings + invest;
  return {
    'income': income,
    'living': living,
    'estimated': living - recorded,
    'debtPay': debtPay,
    'savings': savings,
    'invest': invest,
    'loanIn': loanIn,
    'loanOut': loanOut,
    'total': total,
    'left': income + loanIn - loanOut - total,
    'debtEnd': records(data, 'debts')
        .fold(0.0, (sum, d) => sum + debtBalance(data, d, month, now)),
    'savingsEnd': records(data, 'savings')
        .fold(0.0, (sum, s) => sum + savingAt(data, s, month, now)),
    'investEnd': sumRows(records(data, 'exp').where((e) =>
        e['investId'] != null &&
        (e['m'] as String).compareTo(month) <= 0 &&
        (e['paid'] == true || (e['m'] as String).compareTo(now) >= 0))),
    'receivable': receivable,
  };
}

const annualFlows = <String, String>{
  'income': 'Ingresos',
  'living': 'Gastos sin deudas',
  'estimated': 'Gasto base estimado incluido',
  'debtPay': 'Pagos de deudas',
  'savings': 'Tus aportes a ahorros',
  'invest': 'Inversiones',
  'loanIn': 'Préstamos: entradas',
  'loanOut': 'Préstamos: salidas',
  'total': 'Total gastos y aportes',
  'left': 'A favor / en contra',
};
const annualStocks = <String, String>{
  'debtEnd': 'Deuda al cierre',
  'savingsEnd': 'Ahorro compartido al cierre',
  'investEnd': 'Aportes invertidos al cierre',
  'receivable': 'Por cobrar al cierre',
};
