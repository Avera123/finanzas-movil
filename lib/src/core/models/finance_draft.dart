import 'dart:convert';
import 'finance_document.dart';

/// Copy-on-write document. Unknown keys survive edits and serialization.
class FinanceDraft {
  FinanceDraft(FinanceDocument source)
      : baseVersion = source.version,
        fields = jsonDecode(jsonEncode(source.fields)) as Map<String, dynamic>;
  final int baseVersion;
  final Map<String, dynamic> fields;
  Map<String, dynamic> freezePayload() {
    if (fields['version'] != baseVersion) {
      throw const FormatException('Draft version changed');
    }
    return Map<String, dynamic>.unmodifiable(
        FinanceDocument.fromJson(fields).fields);
  }
}
