import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/finance_draft.dart';
import 'package:finanzas_movil/src/features/movements/domain/finance_commands.dart';
import 'package:finanzas_movil/src/features/plans/domain/plan_engine.dart';
import 'package:finanzas_movil/src/features/plans/domain/capital_engine.dart';
import 'package:finanzas_movil/src/features/plans/domain/capital_commands.dart';

void main() {
  final reference = jsonDecode(
      File('test/fixtures/capital_reference.json').readAsStringSync()) as Map;
  CapitalCommands commands(Map data) => CapitalCommands(FinanceCommands(
          FinanceDraft(FinanceDocument.fromJson(<String, dynamic>{
        'version': 1,
        'acc': [],
        'exp': [],
        'cats': [],
        'meths': ['Transferencia'],
        ...data
      }))));
  for (final c in reference['investmentCases'] as List) {
    test('JS investment parity ${c['name']}', () {
      final data = c['data'] as Map;
      final inv = c['inv'] as Map;
      final rows = investmentPlan(data, inv, c['now'] as String);
      expect(rows, c['expectedRows']);
      final expanded = {
        ...data,
        'exp': [
          ...data['exp'],
          ...rows.map((r) => {...r, 'paid': false, 'investId': 'i'})
        ]
      };
      expect(investmentPath(expanded, inv), c['expectedPath']);
    });
  }
  for (final c in reference['goals'] as List) {
    test('JS goal parity ${c['annual']}%', () {
      expect(
          paymentForGoal(
              number(c['target']), c['months'] as int, number(c['annual'])),
          c['expected']);
    });
  }
  for (final c in reference['contributionCases'] as List) {
    test('JS contribution parity ${c['name']}', () {
      final cmd = commands(c['data'] as Map);
      cmd.setContribution('c', true);
      cmd.setContribution('c', true);
      expect(cmd.data['acc'], c['expected']['acc']);
      expect(cmd.data['contrib'], c['expected']['contrib']);
      cmd.setContribution('c', false);
      expect(cmd.data['acc'], c['data']['acc']);
    });
  }
  test('Shared reconciliation moves foreign contribution only once', () {
    final cmd = commands(reference['reconcileInput'] as Map);
    cmd.reconcileShared();
    cmd.reconcileShared();
    expect(cmd.data['acc'], reference['reconcileExpected']['acc']);
    expect(cmd.data['fundSeen'], reference['reconcileExpected']['fundSeen']);
  });
  test('Owner cannot mark another registered member contribution', () {
    final cmd = commands(reference['reconcileInput'] as Map);
    expect(() => cmd.setContribution('foreign', false), throwsFormatException);
    expect(cmd.data['acc'], reference['reconcileInput']['acc']);
  });
  test('Non-owner cannot remove shared savings or edit its members', () {
    final cmd = commands(reference['reconcileInput'] as Map);
    cmd.fund('s')['isOwner'] = false;
    expect(() => cmd.removeSaving('s'), throwsFormatException);
    expect(
        () => cmd.addMember('s', 'Third', 'third@example.test', 100, '2026-11'),
        throwsFormatException);
    expect(canEditContribution(cmd.fund('s'), {'mine': false, 'email': ''}),
        isFalse);
  });
  test(
      'Withdrawal and undo preserve accounts; deleting saving does not reverse balances',
      () {
    final cmd =
        commands((reference['contributionCases'] as List).first['data'] as Map);
    cmd.extraContribution('s', 'me', '2026-11', 100, true);
    expect(records(cmd.data, 'acc').first['bal'], 1100);
    expect(records(cmd.data, 'acc').last['bal'], 400);
    cmd.removeExtra(records(cmd.data, 'contrib').last['id'] as String);
    expect(records(cmd.data, 'acc').first['bal'], 1000);
    cmd.setContribution('c', true);
    final balances = jsonEncode(cmd.data['acc']);
    cmd.removeSaving('s');
    expect(jsonEncode(cmd.data['acc']), balances);
  });
  test(
      'Investment shifting recalculates destination percent and leaves paid rows',
      () {
    final cmd = commands({
      'usd': 1000,
      'rate': 4,
      'inc': {'2027-01': 2000}
    });
    cmd.saveInvestment(
        name: 'Synthetic',
        kind: 'Fondo',
        mode: 'percent',
        value: 10,
        months: 3,
        rate: 0,
        start: '2026-11',
        now: '2026-11');
    final inv = records(cmd.data, 'investments').single;
    final first = records(cmd.data, 'exp').first;
    first['paid'] = true;
    cmd.shiftInvestment(inv['id'] as String, 1, '2026-11');
    final pending =
        records(cmd.data, 'exp').where((e) => e['paid'] != true).toList();
    expect(first['m'], '2026-11');
    expect(first['amt'], 400);
    expect(pending.first['m'], '2027-01');
    expect(pending.first['amt'], 200);
  });
  test(
      'Creating a saving and adding partner generates future monthly contributions',
      () {
    final cmd = commands({});
    cmd.saveSaving(
        name: 'Synthetic joint saving',
        bank: 'Fixture',
        start: 0,
        startMonth: '2026-11',
        now: '2026-11',
        ownerEmail: 'me@example.test',
        ownMonthly: 100);
    final saving = records(cmd.data, 'savings').single;
    cmd.addMember(saving['id'] as String, 'Partner', 'partner@example.test',
        100, '2026-11');
    expect(records(cmd.data, 'contrib').length, 24);
    expect(records(saving, 'members').length, 2);
    expect(
        records(cmd.data, 'contrib').every((c) => c['done'] == false), isTrue);
  });
}
