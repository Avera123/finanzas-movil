import '../../../core/models/finance_document.dart';

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

String monthLabel(DateTime date) => '${const [
      "Enero",
      "Febrero",
      "Marzo",
      "Abril",
      "Mayo",
      "Junio",
      "Julio",
      "Agosto",
      "Septiembre",
      "Octubre",
      "Noviembre",
      "Diciembre"
    ][date.month - 1]} ${date.year}';

String cop(num value) {
  final digits = value.abs().round().toString();
  final grouped =
      digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${value < 0 ? "−" : ""}\$ $grouped COP';
}

class ExpenseView {
  ExpenseView(Map row)
      : id = row['id'] as String?,
        linkedPlan = row['debtId'] != null || row['investId'] != null,
        series = row['seriesId'] != null,
        name = row['name'] as String,
        category = row['cat'] as String,
        amount = (row['amt'] as num).toDouble(),
        paid = row['paid'] as bool,
        accountId = row['acc'] as String?;
  final String name, category;
  final String? id;
  final bool linkedPlan, series;
  final double amount;
  final bool paid;
  final String? accountId;
}

/// Read-only Resumen metrics from App.jsx: incomeOf, tot and category totals.
/// Does not represent monthly.left or projected net worth from Annual.
class MonthSummary {
  MonthSummary(FinanceDocument document, DateTime month) {
    final fields = document.fields;
    final key = monthKey(month);
    final inc = fields['inc'];
    final override = inc is Map ? inc[key] : null;
    recordedIncome = override != null;
    final usd = fields['usd'], rate = fields['rate'];
    income = override is num
        ? override.toDouble()
        : usd is num && rate is num
            ? (usd * rate).toDouble()
            : null;
    final rows = fields['exp'] as List;
    final selected = rows.where((row) => row is Map && row['m'] == key);
    for (final row in selected.cast<Map>()) {
      if (row['name'] is! String ||
          row['cat'] is! String ||
          row['amt'] is! num ||
          row['paid'] is! bool ||
          (row['acc'] != null && row['acc'] is! String)) {
        throw const FormatException('Invalid expense');
      }
      expenses.add(ExpenseView(row));
    }
    for (final row in expenses) {
      total += row.amount;
      if (!row.paid) pending += row.amount;
      categories.update(row.category, (value) => value + row.amount,
          ifAbsent: () => row.amount);
    }
  }
  late final bool recordedIncome;
  late final double? income;
  final expenses = <ExpenseView>[];
  final categories = <String, double>{};
  double total = 0, pending = 0;
}
