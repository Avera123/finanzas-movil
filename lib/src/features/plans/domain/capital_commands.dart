import '../../movements/domain/finance_commands.dart';
import 'plan_commands.dart';
import 'plan_engine.dart';
import 'capital_engine.dart';

class CapitalCommands {
  CapitalCommands(this.commands);
  final FinanceCommands commands;
  Map<String, dynamic> get data => commands.data;
  void saveInvestment(
      {String? id,
      required String name,
      required String kind,
      required String mode,
      required double value,
      required int months,
      required double rate,
      required String start,
      required String now,
      String? account,
      double? target,
      String? goalMonth}) {
    monthNumber(start);
    if (mode == 'goal') {
      if (target == null || goalMonth == null) {
        throw const FormatException('Completa meta y fecha.');
      }
      months = monthNumber(goalMonth) - monthNumber(start) + 1;
      value = paymentForGoal(target, months, rate).toDouble();
    }
    if (name.trim().isEmpty ||
        !value.isFinite ||
        value <= 0 ||
        !rate.isFinite ||
        rate < 0 ||
        months < 1 ||
        months > 600 ||
        !['fixed', 'percent', 'goal'].contains(mode) ||
        (mode == 'percent' && value > 100)) {
      throw const FormatException('Revisa nombre, valor, plazo y rendimiento.');
    }
    data['investments'] ??= <Map>[];
    final existing = id == null
        ? null
        : records(data, 'investments').firstWhere((i) => i['id'] == id);
    if (existing != null && existing['startM'] != start) {
      throw const FormatException('Conserva el mes inicial.');
    }
    final inv = existing ?? <String, dynamic>{'id': commands.newId()};
    inv.addAll(<String, dynamic>{
      'name': name.trim(),
      'kind': kind,
      'mode': mode == 'percent' ? 'percent' : 'fixed',
      'value': value,
      'startM': start,
      'months': months,
      'rate': rate,
      'acc': account,
      'target': mode == 'goal' ? target : existing?['target'],
      'resumeM': existing?['resumeM']
    });
    if (existing == null) (data['investments'] as List).add(inv);
    final cats = data['cats'] as List;
    if (!cats.contains('Inversión')) cats.add('Inversión');
    final rows = investmentPlan(data, inv, now);
    data['exp'] = records(data, 'exp')
        .where((e) => !(e['investId'] == inv['id'] && e['paid'] != true))
        .toList();
    final methods = data['meths'] as List;
    if (methods.isEmpty) {
      throw const FormatException('Configura un tipo de pago.');
    }
    for (final row in rows) {
      (data['exp'] as List).add({
        'id': commands.newId(),
        ...row,
        'name': inv['name'],
        'cat': 'Inversión',
        'meth':
            methods.contains('Transferencia') ? 'Transferencia' : methods.first,
        'acc': inv['acc'],
        'paid': false,
        'investId': inv['id']
      });
    }
  }

  void removeInvestment(String id) {
    data['exp'] = records(data, 'exp')
        .where((e) => !(e['investId'] == id && e['paid'] != true))
        .toList();
    for (final row in records(data, 'exp')) {
      if (row['investId'] == id) row['investId'] = null;
    }
    data['investments'] =
        records(data, 'investments').where((i) => i['id'] != id).toList();
  }

  void shiftInvestment(String id, int months, String now) {
    if (months < 1 || months > 600) {
      throw const FormatException('Mueve entre 1 y 600 meses hacia adelante.');
    }
    final inv = records(data, 'investments').firstWhere((i) => i['id'] == id);
    final pending = records(data, 'exp')
        .where((e) => e['investId'] == id && e['paid'] != true)
        .toList()
      ..sort((a, b) => (a['m'] as String).compareTo(b['m'] as String));
    final first =
        pending.isEmpty || (pending.first['m'] as String).compareTo(now) < 0
            ? now
            : pending.first['m'] as String;
    inv['resumeM'] = addMonth(first, months);
    for (var i = 0; i < pending.length; i++) {
      final month = addMonth(inv['resumeM'] as String, i);
      pending[i]['m'] = month;
      pending[i]['amt'] = investmentAmount(data, inv, month);
    }
  }

  Map fund(String id) =>
      records(data, 'savings').firstWhere((f) => f['id'] == id);
  Map member(Map fund, String id) =>
      records(fund, 'members').firstWhere((p) => p['id'] == id);
  void requireOwner(Map saving) {
    if (saving['isOwner'] != true) {
      throw const FormatException(
          'Solo el propietario puede editar o eliminar el ahorro.');
    }
  }

  void requireMember(Map saving, String id) {
    if (!canEditContribution(saving, member(saving, id))) {
      throw const FormatException(
          'Solo puedes cambiar tus aportes o los miembros sin correo de un ahorro propio.');
    }
  }

  void extendSavings(String now) {
    data['contrib'] ??= <Map>[];
    for (final saving in records(data, 'savings')) {
      final start = (saving['startM'] as String).compareTo(now) > 0
          ? saving['startM'] as String
          : now;
      var end = addMonth(now, 11);
      if (saving['endM'] != null &&
          (saving['endM'] as String).compareTo(end) < 0) {
        end = saving['endM'] as String;
      }
      for (final p in records(saving, 'members')) {
        if (number(p['monthly']) <= 0) continue;
        for (var month = start;
            month.compareTo(end) <= 0;
            month = addMonth(month, 1)) {
          if (records(data, 'contrib').any((c) =>
              c['savingId'] == saving['id'] &&
              c['memberId'] == p['id'] &&
              c['m'] == month &&
              c['extra'] != true)) {
            continue;
          }
          (data['contrib'] as List).add({
            'id': commands.newId(),
            'savingId': saving['id'],
            'memberId': p['id'],
            'm': month,
            'amt': p['monthly'],
            'done': false,
            'extra': false
          });
        }
      }
    }
  }

  void markSeen(String id) {
    data['fundSeen'] ??= <String, dynamic>{};
    for (final c
        in records(data, 'contrib').where((c) => c['savingId'] == id)) {
      data['fundSeen'][c['id']] = c['done'] == true ? c['amt'] : 0;
    }
  }

  void saveSaving(
      {String? id,
      required String name,
      required String bank,
      required double start,
      required String startMonth,
      String? endMonth,
      double? target,
      String? account,
      required String now,
      required String ownerEmail,
      required double ownMonthly,
      String? ownAccount}) {
    monthNumber(startMonth);
    if (endMonth != null) monthNumber(endMonth);
    if (name.trim().isEmpty ||
        !start.isFinite ||
        start < 0 ||
        !ownMonthly.isFinite ||
        ownMonthly < 0 ||
        (target != null && (!target.isFinite || target <= 0)) ||
        (endMonth != null && endMonth.compareTo(startMonth) < 0)) {
      throw const FormatException('Revisa nombre, saldos, aportes y meses.');
    }
    data['savings'] ??= <Map>[];
    final existing = id == null ? null : fund(id);
    if (existing != null) requireOwner(existing);
    if (existing != null && existing['startM'] != startMonth) {
      throw const FormatException('Conserva el mes inicial del ahorro.');
    }
    final saving = existing ??
        <String, dynamic>{
          'id': commands.newId(),
          'isOwner': true,
          'members': <Map>[
            {
              'id': commands.newId(),
              'name': 'Tú',
              'email': ownerEmail,
              'mine': true,
              'monthly': ownMonthly,
              'acc': ownAccount
            }
          ]
        };
    saving.addAll(<String, dynamic>{
      'name': name.trim(),
      'bank': bank.trim().isEmpty ? null : bank.trim(),
      'acc': account,
      'start': start,
      'startM': startMonth,
      'endM': endMonth,
      'target': target
    });
    for (final p
        in records(saving, 'members').where((p) => p['mine'] == true)) {
      p['monthly'] = ownMonthly;
      p['acc'] = ownAccount;
    }
    if (existing == null) {
      (data['savings'] as List).add(saving);
    } else {
      resyncSaving(saving['id'] as String, now);
    }
    extendSavings(now);
    markSeen(saving['id'] as String);
  }

  void resyncSaving(String id, String now) {
    data['contrib'] = records(data, 'contrib')
        .where((c) =>
            c['savingId'] != id || c['done'] == true || c['extra'] == true)
        .toList();
    extendSavings(now);
  }

  void addMember(
      String id, String name, String email, double monthly, String now) {
    final saving = fund(id);
    requireOwner(saving);
    email = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        !monthly.isFinite ||
        monthly < 0 ||
        (email.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const FormatException('Revisa nombre, correo y aporte.');
    }
    if (email.isNotEmpty &&
        records(saving, 'members').any((p) => p['email'] == email)) {
      throw const FormatException('Ese correo ya participa.');
    }
    (saving['members'] as List).add({
      'id': commands.newId(),
      'name': name.trim(),
      'email': email,
      'mine': false,
      'monthly': monthly,
      'acc': null
    });
    resyncSaving(id, now);
    markSeen(id);
  }

  void setContribution(String id, bool done) {
    final c = records(data, 'contrib').firstWhere((c) => c['id'] == id);
    final saving = fund(c['savingId'] as String);
    final p = member(saving, c['memberId'] as String);
    requireMember(saving, p['id'] as String);
    if (c['done'] == done) return;
    final from = p['mine'] == true ? p['acc'] as String? : null;
    final to = saving['acc'] as String?;
    final delta = number(c['amt']) * (done ? 1 : -1);
    if (from != to) {
      final plans = PlanCommands(commands);
      plans.adjustAccount(from, -delta);
      plans.adjustAccount(to, delta);
    }
    c['done'] = done;
  }

  void linkSavingAccounts(
      String id, String? fundAccount, String? sourceAccount) {
    final saving = fund(id);
    saving['acc'] = fundAccount;
    for (final p
        in records(saving, 'members').where((p) => p['mine'] == true)) {
      p['acc'] = sourceAccount;
    }
    markSeen(id);
  }

  void editMember(String savingId, String memberId, String name, String email,
      double monthly, String now) {
    final saving = fund(savingId);
    requireOwner(saving);
    final p = member(saving, memberId);
    email = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        !monthly.isFinite ||
        monthly < 0 ||
        (email.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const FormatException('Revisa persona, correo y aporte.');
    }
    if (p['mine'] == true && email != p['email']) {
      throw const FormatException('No cambies tu correo desde un ahorro.');
    }
    p['name'] = name.trim();
    p['email'] = email;
    p['monthly'] = monthly;
    resyncSaving(savingId, now);
    markSeen(savingId);
  }

  void removeMember(String savingId, String memberId, String now) {
    final saving = fund(savingId);
    requireOwner(saving);
    if (member(saving, memberId)['mine'] == true) {
      throw const FormatException(
          'No puedes quitar tu participación desde este control.');
    }
    saving['members'] =
        records(saving, 'members').where((p) => p['id'] != memberId).toList();
    resyncSaving(savingId, now);
    markSeen(savingId);
  }

  void setContributionAmount(String id, double amount) {
    final c = records(data, 'contrib').firstWhere((c) => c['id'] == id);
    requireMember(fund(c['savingId'] as String), c['memberId'] as String);
    if (c['done'] == true ||
        c['extra'] == true ||
        !amount.isFinite ||
        amount < 0) {
      throw const FormatException(
          'Solo puedes editar un aporte mensual pendiente.');
    }
    c['amt'] = amount;
  }

  void extraContribution(String savingId, String memberId, String month,
      double amount, bool withdrawal) {
    monthNumber(month);
    final saving = fund(savingId);
    requireMember(saving, memberId);
    if (!amount.isFinite ||
        amount <= 0 ||
        (withdrawal && amount > savingBalance(data, saving))) {
      throw const FormatException(
          'El retiro no puede superar el ahorro y el monto debe ser positivo.');
    }
    final id = commands.newId();
    data['contrib'] ??= <Map>[];
    (data['contrib'] as List).add({
      'id': id,
      'savingId': savingId,
      'memberId': memberId,
      'm': month,
      'amt': withdrawal ? -amount : amount,
      'done': false,
      'extra': true
    });
    setContribution(id, true);
  }

  void removeExtra(String id) {
    final c = records(data, 'contrib').firstWhere((c) => c['id'] == id);
    if (c['extra'] != true) {
      throw const FormatException('No es un aporte extra.');
    }
    setContribution(id, false);
    data['contrib'] =
        records(data, 'contrib').where((c) => c['id'] != id).toList();
  }

  void removeSaving(String id) {
    requireOwner(fund(id));
    data['savings'] =
        records(data, 'savings').where((s) => s['id'] != id).toList();
    data['contrib'] =
        records(data, 'contrib').where((c) => c['savingId'] != id).toList();
  }

  void reconcileShared() {
    data['fundSeen'] ??= <String, dynamic>{};
    for (final c in records(data, 'contrib')) {
      final matching =
          records(data, 'savings').where((f) => f['id'] == c['savingId']);
      if (matching.isEmpty) continue;
      final saving = matching.first;
      final members =
          records(saving, 'members').where((p) => p['id'] == c['memberId']);
      if (members.isEmpty) continue;
      final p = members.first;
      if (saving['acc'] == null ||
          p['email'] == null ||
          p['email'] == '' ||
          p['mine'] == true) {
        continue;
      }
      final due = c['done'] == true ? number(c['amt']) : 0.0;
      final seen = number(data['fundSeen'][c['id']] ?? 0);
      if (due == seen) continue;
      PlanCommands(commands).adjustAccount(saving['acc'] as String, due - seen);
      data['fundSeen'][c['id']] = due;
    }
  }
}
