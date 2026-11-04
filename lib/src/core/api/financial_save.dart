import '../models/finance_document.dart';
import '../models/finance_draft.dart';

enum SaveStatus {
  review,
  saving,
  saved,
  conflict,
  uncertain,
  rejected,
  sessionChanged,
  cancelled
}

class SaveFailure implements Exception {
  const SaveFailure(this.status);
  final SaveStatus status;
}

abstract interface class FinancialGateway {
  int get sessionGeneration;
  Future<int> putDocument(Map<String, dynamic> payload, int generation);
  Future<FinanceDocument> readDocument();
}

/// One operation requires a new preview. An uncertain result cannot be retried.
class FinancialSave {
  static final _busy = Expando<bool>();
  FinancialSave(this.gateway, FinanceDraft draft)
      : generation = gateway.sessionGeneration,
        payload = draft.freezePayload();
  final FinancialGateway gateway;
  final int generation;
  final Map<String, dynamic> payload;
  SaveStatus status = SaveStatus.review;
  FinanceDocument? savedDocument;

  void cancel() {
    if (status == SaveStatus.review) status = SaveStatus.cancelled;
  }

  Future<void> confirm() async {
    if (status != SaveStatus.review) return;
    if (_busy[gateway] == true) {
      status = SaveStatus.rejected;
      return;
    }
    if (generation != gateway.sessionGeneration) {
      status = SaveStatus.sessionChanged;
      return;
    }
    status = SaveStatus.saving;
    _busy[gateway] = true;
    try {
      final next = await gateway.putDocument(payload, generation);
      if (generation != gateway.sessionGeneration) {
        status = SaveStatus.sessionChanged;
        return;
      }
      if (next <= (payload['version'] as int)) {
        status = SaveStatus.uncertain;
        return;
      }
      final refreshed = await gateway.readDocument();
      if (generation != gateway.sessionGeneration) {
        status = SaveStatus.sessionChanged;
        return;
      }
      if (refreshed.version < next) {
        status = SaveStatus.uncertain;
        return;
      }
      savedDocument = refreshed;
      status = SaveStatus.saved;
    } on SaveFailure catch (e) {
      status = generation == gateway.sessionGeneration
          ? e.status
          : SaveStatus.sessionChanged;
    } catch (_) {
      status = generation == gateway.sessionGeneration
          ? SaveStatus.uncertain
          : SaveStatus.sessionChanged;
    } finally {
      _busy[gateway] = false;
    }
  }
}
