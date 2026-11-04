import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/core/models/user_profile.dart';
import 'support/fakes.dart';

void main() {
  test('El snapshot conserva versión y campos no usados por el resumen', () {
    final json = {
      ...stateFixture(),
      'version': 8,
      'investments': [
        {'id': 'synthetic-investment', 'resumeM': '2027-01'}
      ],
      'futureExtension': {'enabled': true},
    };
    final doc = FinanceDocument.fromJson(json);
    expect(doc.version, 8);
    expect(doc.summary.netBalance, 800000);
    expect(doc.fields['investments'], json['investments']);
    expect(doc.fields['futureExtension'], {'enabled': true});
  });

  test('No se puede alterar el documento ni por listas o mapas anidados', () {
    final doc = FinanceDocument.fromJson(stateFixture());
    expect(() => doc.fields['version'] = 2, throwsUnsupportedError);
    final accounts = doc.fields['acc'] as List;
    expect(() => accounts.add({}), throwsUnsupportedError);
    expect(() => (accounts.first as Map)['bal'] = 0, throwsUnsupportedError);
  });

  test('Modificar la respuesta original no altera el snapshot', () {
    final json = stateFixture();
    final doc = FinanceDocument.fromJson(json);
    (json['acc'] as List).clear();
    expect((doc.fields['acc'] as List).length, 2);
    expect(doc.summary.accounts.length, 2);
  });

  test('Versiones ausentes, de otro tipo o no positivas son errores', () {
    for (final v in [null, 0, -1, '2', 1.5, true]) {
      expect(() => FinanceDocument.fromJson({...stateFixture(), 'version': v}),
          throwsFormatException);
    }
  });

  test('No acepta valores no JSON o montos infinitos en campos desconocidos',
      () {
    for (final v in [DateTime.utc(2026), double.infinity, double.nan]) {
      expect(() => FinanceDocument.fromJson({...stateFixture(), 'unknown': v}),
          throwsFormatException);
    }
  });

  test('Solo un perfil admin validado tiene capacidad de administración', () {
    expect(UserProfile.fromJson(profileFixture()).canManageUsers, false);
    expect(
        UserProfile.fromJson({...profileFixture(), 'role': 'admin'})
            .canManageUsers,
        true);
    for (final role in ['editor', '', null]) {
      expect(() => UserProfile.fromJson({...profileFixture(), 'role': role}),
          throwsFormatException);
    }
    expect(
        () => UserProfile.fromJson(
            {...profileFixture(), 'role': 'admin', 'active': false}),
        throwsFormatException);
  });
}
