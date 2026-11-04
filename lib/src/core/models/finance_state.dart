class FinanceAccount {
  const FinanceAccount(this.id, this.name, this.type, this.balance);
  final String id;
  final String name;
  final String type;
  final double balance;
  factory FinanceAccount.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['id'] is! String ||
        json['name'] is! String ||
        json['type'] is! String ||
        json['bal'] is! num ||
        !(json['bal'] as num).isFinite) {
      throw const FormatException('Invalid account');
    }
    return FinanceAccount(json['id'] as String, json['name'] as String,
        json['type'] as String, (json['bal'] as num).toDouble());
  }
}

class FinanceState {
  const FinanceState(this.accounts, this.expenseCount);
  final List<FinanceAccount> accounts;
  final int expenseCount;
  // Matches the web app: this is account balance, not total net worth.
  double get netBalance => accounts.fold(
      0.0, (sum, a) => sum + (a.type == 'Crédito' ? -a.balance : a.balance));
  factory FinanceState.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['acc'] is! List ||
        json['exp'] is! List) {
      throw const FormatException('Invalid state');
    }
    return FinanceState(
        List.unmodifiable((json['acc'] as List).map(FinanceAccount.fromJson)),
        (json['exp'] as List).length);
  }
}
