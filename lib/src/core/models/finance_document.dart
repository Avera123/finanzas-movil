import 'finance_state.dart';

/// Read-only snapshot. Do not build a financial PUT from a partial summary.
class FinanceDocument {
  const FinanceDocument._(this.version, this.fields, this.summary);
  final int version;
  final Map<String, Object?> fields;
  final FinanceState summary;

  factory FinanceDocument.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['version'] is! int ||
        (json['version'] as int) < 1) {
      throw const FormatException('Invalid financial document version');
    }
    final summary = FinanceState.fromJson(json);
    return FinanceDocument._(
        json['version'] as int, _freeze(json) as Map<String, Object?>, summary);
  }

  static Object? _freeze(Object? value) {
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw const FormatException('Invalid document keys');
      }
      return Map<String, Object?>.unmodifiable(
          value.map((key, item) => MapEntry(key as String, _freeze(item))));
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_freeze));
    }
    if (value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite)) {
      return value;
    }
    throw const FormatException('Invalid JSON document value');
  }
}
