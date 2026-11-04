import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/api/financial_save.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/finance_draft.dart';
import 'package:finanzas_movil/src/features/movements/domain/finance_commands.dart';

FinanceDocument fixture({int version = 1}) => FinanceDocument.fromJson({
      'version': version,
      'extra': {
        'preserve': [1, 2]
      },
      'acc': [
        {'id': 'a', 'name': 'Savings', 'type': 'Ahorros', 'bal': 1000},
        {'id': 'b', 'name': 'Credit', 'type': 'Crédito', 'bal': 50}
      ],
      'exp': [
        {
          'id': 'e',
          'name': 'Test',
          'cat': 'Vida',
          'm': '2026-11',
          'amt': 100,
          'paid': false,
          'acc': 'a'
        }
      ],
    });

class Gateway implements FinancialGateway {
  @override
  int sessionGeneration = 0;
  int writes = 0;
  SaveFailure? failure;
  Completer<void>? waiting;
  bool readFails = false;
  Map<String, dynamic>? sent;
  @override
  Future<int> putDocument(Map<String, dynamic> payload, int generation) async {
    writes++;
    sent = payload;
    await waiting?.future;
    if (failure != null) throw failure!;
    return 2;
  }

  @override
  Future<FinanceDocument> readDocument() async {
    if (readFails) throw StateError('connection lost');
    return fixture(version: 2);
  }
}

void main() {
  test('Draft preserves unknown fields and source is unchanged on cancellation',
      () {
    final source = fixture();
    final draft = FinanceDraft(source);
    FinanceCommands(draft).togglePayment('e');
    final gateway = Gateway();
    final operation = FinancialSave(gateway, draft)..cancel();
    expect(operation.payload['extra'], source.fields['extra']);
    expect(source.summary.accounts.first.balance, 1000);
    expect(gateway.writes, 0);
    expect(operation.status, SaveStatus.cancelled);
  });
  test('Payment and undo are inverse for debit and credit', () {
    final draft = FinanceDraft(fixture());
    final commands = FinanceCommands(draft);
    commands.togglePayment('e');
    expect(commands.accounts.first['bal'], 900);
    commands.togglePayment('e');
    expect(commands.accounts.first['bal'], 1000);
    commands.expense('e')['acc'] = 'b';
    commands.togglePayment('e');
    expect(commands.accounts.last['bal'], 150);
    commands.togglePayment('e');
    expect(commands.accounts.last['bal'], 50);
  });
  test('Series moves forward across year, keeping paid rows', () {
    final commands = FinanceCommands(FinanceDraft(fixture()));
    commands.addExpense(
        name: 'Series',
        amount: 20,
        month: '2026-12',
        category: 'Vida',
        method: 'Test',
        repeat: 3);
    final rows = commands.expenses
        .cast<Map>()
        .where((e) => e['seriesId'] != null)
        .toList();
    rows.first['paid'] = true;
    commands.move(rows[1]['id'] as String, '2027-03', series: true);
    expect(rows.map((e) => e['m']), ['2026-12', '2027-03', '2027-04']);
  });
  test('Paid linked installment cannot be deleted or moved as plain expense',
      () {
    final c = FinanceCommands(FinanceDraft(fixture()));
    c.expense('e')['debtId'] = 'plan';
    expect(() => c.deleteExpense('e'), throwsFormatException);
    expect(() => c.move('e', '2027-01'), throwsFormatException);
  });
  test('Payload frozen before preview survives subsequent draft changes', () {
    final draft = FinanceDraft(fixture());
    final op = FinancialSave(Gateway(), draft);
    draft.fields['extra']['preserve'].add(3);
    expect((op.payload['extra'] as Map)['preserve'], [1, 2]);
    expect(() => op.payload['version'] = 99, throwsUnsupportedError);
  });
  test('Double tap and parallel operation only send once', () async {
    final gateway = Gateway()..waiting = Completer<void>();
    final op = FinancialSave(gateway, FinanceDraft(fixture()));
    final first = op.confirm();
    await op.confirm();
    final other = FinancialSave(gateway, FinanceDraft(fixture()));
    await other.confirm();
    expect(other.status, SaveStatus.rejected);
    expect(gateway.writes, 1);
    gateway.waiting!.complete();
    await first;
    expect(op.status, SaveStatus.saved);
  });
  for (final status in [
    SaveStatus.conflict,
    SaveStatus.uncertain,
    SaveStatus.rejected,
    SaveStatus.sessionChanged
  ]) {
    test('$status never retries or reports success', () async {
      final gateway = Gateway()..failure = SaveFailure(status);
      final op = FinancialSave(gateway, FinanceDraft(fixture()));
      await op.confirm();
      await op.confirm();
      expect(gateway.writes, 1);
      expect(op.status, status);
    });
  }
  test('Session change before confirmation prevents sending old draft',
      () async {
    final gateway = Gateway();
    final op = FinancialSave(gateway, FinanceDraft(fixture()));
    gateway.sessionGeneration++;
    await op.confirm();
    expect(gateway.writes, 0);
    expect(op.status, SaveStatus.sessionChanged);
  });
  test('Session change during commit discards returned state', () async {
    final gateway = Gateway()..waiting = Completer<void>();
    final op = FinancialSave(gateway, FinanceDraft(fixture()));
    final pending = op.confirm();
    gateway.sessionGeneration++;
    gateway.waiting!.complete();
    await pending;
    expect(op.status, SaveStatus.sessionChanged);
    expect(op.savedDocument, isNull);
  });
  test('Commit succeeded but refresh failed remains uncertain, never reapplied',
      () async {
    final gateway = Gateway()..readFails = true;
    final op = FinancialSave(gateway, FinanceDraft(fixture()));
    await op.confirm();
    await op.confirm();
    expect(op.status, SaveStatus.uncertain);
    expect(gateway.writes, 1);
  });
  test(
      'Income changes reprice only pending percent investments, including zero',
      () {
    final d = FinanceDraft(fixture());
    d.fields['investments'] = [
      {'id': 'i', 'mode': 'percent', 'value': 10}
    ];
    d.fields['inc'] = <String, dynamic>{};
    d.fields['usd'] = 100;
    d.fields['rate'] = 4000;
    d.fields['exp'].addAll([
      {
        'id': 'pending',
        'investId': 'i',
        'm': '2026-11',
        'amt': 20,
        'paid': false
      },
      {'id': 'paid', 'investId': 'i', 'm': '2026-11', 'amt': 20, 'paid': true},
    ]);
    final c = FinanceCommands(d);
    c.setIncome('2026-11', 0);
    expect(c.expense('pending')['amt'], 0);
    expect(c.expense('paid')['amt'], 20);
    c.setIncome('2026-11', null);
    expect(c.expense('pending')['amt'], 40000);
  });
  test(
      'USD credit deposit reduces debt; deleting paid expense reverses balance',
      () {
    final d = FinanceDraft(fixture());
    d.fields['rate'] = 4;
    final c = FinanceCommands(d);
    c.depositUsd('b', 10);
    expect(c.accounts.last['bal'], 10);
    c.togglePayment('e');
    c.deleteExpense('e');
    expect(c.accounts.first['bal'], 1000);
    expect(c.expenses, isEmpty);
  });
  test('Cannot remove used category or tamper with base version', () {
    final d = FinanceDraft(fixture());
    d.fields['cats'] = ['Vida'];
    final c = FinanceCommands(d);
    expect(() => c.removeOption('cats', 'Vida'), throwsFormatException);
    d.fields['version'] = 9;
    expect(d.freezePayload, throwsFormatException);
  });
}
