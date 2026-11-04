import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/finance_draft.dart';
import 'package:finanzas_movil/src/features/movements/domain/finance_commands.dart';
import 'package:finanzas_movil/src/features/plans/domain/plan_engine.dart';
import 'package:finanzas_movil/src/features/plans/domain/plan_commands.dart';

void main() {
  final reference =
      jsonDecode(File('test/fixtures/debt_reference.json').readAsStringSync())
          as Map;
  for (final fixture in reference['cases'] as List) {
    test('JS schedule parity: ${fixture['name']}', () {
      final result = debtSchedule(fixture['data'] as Map,
          fixture['debt'] as Map, fixture['now'] as String);
      expect(result.ok, fixture['expected']['ok']);
      expect(result.rows, fixture['expected']['rows']);
      expect(result.interest,
          closeTo(number(fixture['expected']['interest']), 1e-7));
    });
  }
  for (final row in reference['formulas'] as List) {
    test('JS payment parity ${row['rate']}%', () {
      expect(
          paymentForMonths(number(row['balance']), number(row['rate']),
              row['months'] as int),
          row['expected']);
    });
  }
  for (final row in reference['implied'] as List) {
    test('JS implied interest parity ${row['total']}', () {
      final result = impliedMonthlyRate(
          number(row['total']), number(row['payment']), row['months'] as int);
      expect(
          result,
          row['expected'] == null
              ? isNull
              : closeTo(number(row['expected']), 1e-8));
    });
  }
  PlanCommands makeCommands() =>
      PlanCommands(FinanceCommands(FinanceDraft(FinanceDocument.fromJson({
        'version': 1,
        'usd': 1000,
        'rate': 4,
        'living': 500,
        'cats': ['Vida'],
        'meths': ['Transferencia'],
        'acc': [
          {'id': 'a', 'name': 'Fixture account', 'type': 'Ahorros', 'bal': 5000}
        ],
        'exp': [],
      }))));
  test('Loan partial receipt undo and removal reverse balances exactly', () {
    final c = makeCommands();
    c.createLoan('Fixture person', 1000, '2026-11-01', '2026-12-01', 'a', '');
    expect(records(c.data, 'acc').first['bal'], 4000);
    final loan = records(c.data, 'loans').first;
    c.receiveLoan(loan['id'] as String, 200, '2026-11-04', 'a');
    expect(loanBalance(c.data, loan), 800);
    expect(records(c.data, 'acc').first['bal'], 4200);
    c.undoLoanReceipt(records(c.data, 'loanPay').first['id'] as String);
    expect(records(c.data, 'acc').first['bal'], 4000);
    c.receiveLoan(loan['id'] as String, 300, '2026-11-04', 'a');
    c.removeLoan(loan['id'] as String);
    expect(records(c.data, 'acc').first['bal'], 5000);
    expect(records(c.data, 'loanPay'), isEmpty);
  });
  test('Civil dates reject overflow and label due today without timezone drift',
      () {
    expect(() => civilDate('2026-02-30'), throwsFormatException);
    final loan = {'id': 'l', 'total': 100, 'dueOn': '2026-11-04'};
    expect(loanDueLabel({}, loan, '2026-11-04'), 'Vence hoy');
    expect(loanDueLabel({}, loan, '2026-11-05'), 'Vencido hace 1 días');
  });
  test('Open debt extension preserves edited pending values and paid rows', () {
    final c = makeCommands();
    c.saveDebt(
        name: 'Open fixture',
        mode: 'open',
        total: 0,
        rate: 0,
        value: 100,
        count: 0,
        start: '2026-11',
        now: '2026-11');
    final rows = records(c.data, 'exp');
    rows.first['amt'] = 250;
    c.extendOpen('2026-12');
    expect(records(c.data, 'exp').first['amt'], 250);
    expect(records(c.data, 'exp').length, 13);
  });
  test('Debt removal preserves paid history without moving accounts', () {
    final c = makeCommands();
    c.saveDebt(
        name: 'Fixture',
        mode: 'months',
        total: 1000,
        rate: 0,
        value: 3,
        count: 3,
        start: '2026-11',
        account: 'a',
        now: '2026-11');
    final debt = records(c.data, 'debts').first;
    c.commands.togglePayment(records(c.data, 'exp').first['id'] as String);
    final before = records(c.data, 'acc').first['bal'];
    c.removeDebt(debt['id'] as String);
    expect(records(c.data, 'exp').length, 1);
    expect(records(c.data, 'exp').first['debtId'], isNull);
    expect(records(c.data, 'acc').first['bal'], before);
  });
  test(
      'Conversion preserves amounts and payments instead of recreating existing rows',
      () {
    final c = makeCommands();
    c.data['exp'] = <dynamic>[
      {
        'id': 'old',
        'name': 'Cuota fixture',
        'cat': 'Deuda',
        'amt': 45,
        'm': '2026-10',
        'paid': true
      },
      {
        'id': 'next',
        'name': 'Cuota fixture',
        'cat': 'Deuda',
        'amt': 70,
        'm': '2026-11',
        'paid': false
      },
    ];
    c.convertOpen('Cuota fixture', '2026-11');
    expect(c.commands.expense('old')['paid'], isTrue);
    expect(c.commands.expense('old')['amt'], 45);
    expect(c.commands.expense('next')['amt'], 70);
    expect(records(c.data, 'debts').single['mode'], 'open');
    expect(records(c.data, 'acc').first['bal'], 5000);
  });
  test('A deferred known balance accumulates interest before resumed payments',
      () {
    final c = makeCommands();
    c.saveDebt(
        name: 'Fixture',
        mode: 'cuota',
        total: 1000,
        rate: 2,
        value: 100,
        count: 0,
        start: '2026-11',
        now: '2026-11');
    final id = records(c.data, 'debts').first['id'] as String;
    final before = sumRows(records(c.data, 'exp'));
    c.shiftDebt(id, 3, '2026-11');
    expect(records(c.data, 'exp').first['m'], '2027-02');
    expect(sumRows(records(c.data, 'exp')), greaterThan(before));
  });
}
