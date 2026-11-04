import '../../../core/models/finance_document.dart';
import '../../../core/models/finance_state.dart';
import '../../../core/models/user_profile.dart';

class DashboardSnapshot {
  const DashboardSnapshot(this.profile, this.document);
  final UserProfile profile;
  final FinanceDocument document;
  FinanceState get finances => document.summary;
}
