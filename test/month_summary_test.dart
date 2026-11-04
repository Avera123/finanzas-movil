import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_movil/src/core/app_theme.dart';
import 'package:finanzas_movil/src/core/models/finance_document.dart';
import 'package:finanzas_movil/src/features/dashboard/domain/month_summary.dart';

void main() {
  test('Monthly totals preserve zero override, paid and pending', () {
    final doc = FinanceDocument.fromJson({
      'version': 1,
      'acc': [],
      'usd': 1000,
      'rate': 4000,
      'inc': {'2026-11': 0},
      'exp': [
        {
          'm': '2026-11',
          'name': 'Food',
          'cat': 'Vida',
          'amt': 200,
          'paid': true
        },
        {
          'm': '2026-11',
          'name': 'Debt',
          'cat': 'Deuda',
          'amt': 300,
          'paid': false
        },
        {
          'm': '2026-12',
          'name': 'Future',
          'cat': 'Vida',
          'amt': 900,
          'paid': false
        },
      ]
    });
    final summary = MonthSummary(doc, DateTime(2026, 11));
    expect(summary.income, 0);
    expect(summary.recordedIncome, isTrue);
    expect(summary.total, 500);
    expect(summary.pending, 300);
    expect(summary.categories, {'Vida': 200, 'Deuda': 300});
    final next = MonthSummary(doc, DateTime(2026, 12));
    expect(next.income, 4000000);
    expect(next.recordedIncome, isFalse);
    expect(next.total, 900);
  });
  test('Missing salary is unavailable, not a fabricated zero', () {
    final doc = FinanceDocument.fromJson({'version': 1, 'acc': [], 'exp': []});
    expect(MonthSummary(doc, DateTime(2026, 11)).income, isNull);
  });
  test('Calendar and COP labels handle year boundaries and negative money', () {
    expect(monthKey(DateTime(2026, 13)), '2027-01');
    expect(monthLabel(DateTime(2026, 0)), 'Diciembre 2025');
    expect(cop(-1234567), '−\$ 1.234.567 COP');
  });
  test('Invalid expense never silently lowers a displayed monthly total', () {
    final doc = FinanceDocument.fromJson({
      'version': 1,
      'acc': [],
      'exp': [
        {'m': '2026-11', 'amt': 'invalid'}
      ]
    });
    expect(() => MonthSummary(doc, DateTime(2026, 11)), throwsFormatException);
  });
  test('Every palette meets normal text contrast on surface and buttons', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
    }

    for (final name in themeNames.keys) {
      for (final brightness in Brightness.values) {
        final theme = financeTheme(name, brightness);
        final scheme = theme.colorScheme;
        expect(
            contrast(scheme.primary, scheme.surface), greaterThanOrEqualTo(4.5),
            reason: name);
        expect(contrast(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: name);
        expect(contrast(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: name);
        expect(contrast(scheme.onSurface, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(4.5),
            reason: name);
      }
    }
  });
}
