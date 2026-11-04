import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_state.dart';
import 'support/fakes.dart';

void main() {
  test('Saldo neto resta crédito y suma ahorros y efectivo', () {
    final data = stateFixture();
    (data['acc'] as List)
        .add({'id': 'c', 'name': 'Cash', 'type': 'Efectivo', 'bal': 50000.5});
    expect(FinanceState.fromJson(data).netBalance, 850000.5);
  });
  test('Sin cuentas el saldo es cero', () {
    expect(FinanceState.fromJson({'acc': [], 'exp': []}).netBalance, 0);
  });
  test('Saldo negativo y crédito negativo conservan su signo', () {
    final data = stateFixture();
    data['acc'][0]['bal'] = -500;
    data['acc'][1]['bal'] = -200;
    expect(FinanceState.fromJson(data).netBalance, -300);
  });
  test('Formato inválido no se convierte en un saldo falso de cero', () {
    for (final json in [
      null,
      {},
      {'acc': [], 'exp': null},
      {
        'acc': [
          {'bal': '100'}
        ],
        'exp': []
      }
    ]) {
      expect(() => FinanceState.fromJson(json), throwsFormatException);
    }
    final data = stateFixture();
    data['acc'][0]['bal'] = double.nan;
    expect(() => FinanceState.fromJson(data), throwsFormatException);
  });
}
