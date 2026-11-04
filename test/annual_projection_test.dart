import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/features/dashboard/domain/annual_projection.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/annual_reference.json').readAsStringSync())
          as Map;
  for (final c in fixture['cases'] as List) {
    test('Annual parity with verified JS: ${c['month']}', () {
      final before = jsonEncode(fixture['data']);
      final actual = annualMonth(fixture['data'] as Map, c['month'] as String,
          fixture['now'] as String);
      final expected = c['expected'] as Map;
      expect(actual.keys.toSet(), expected.keys.where((k) => k != 'k').toSet());
      for (final key in actual.keys) {
        expect(actual[key], closeTo((expected[key] as num).toDouble(), .00001),
            reason: key);
      }
      expect(jsonEncode(fixture['data']), before);
    });
  }
}
