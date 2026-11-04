import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/backend_client.dart';
import '../../../core/api/financial_save.dart';
import '../../../core/models/finance_document.dart';
import '../../../core/models/finance_draft.dart';
import '../../dashboard/domain/month_summary.dart';
import '../../dashboard/application/dashboard_controller.dart';
import '../domain/finance_commands.dart';

/// The route owns one immutable preview and blocks navigation while saving.
class OperationScreen extends ConsumerStatefulWidget {
  const OperationScreen(
      {super.key,
      required this.document,
      required this.title,
      required this.prepare});
  final FinanceDocument document;
  final String title;
  final void Function(FinanceCommands) prepare;
  @override
  ConsumerState<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends ConsumerState<OperationScreen> {
  FinancialSave? operation;
  String? preparationError;
  late FinanceDraft draft;
  @override
  void initState() {
    super.initState();
    try {
      draft = FinanceDraft(widget.document);
      final commands = FinanceCommands(draft);
      widget.prepare(commands);
      commands.syncPercentInvestments();
      operation = FinancialSave(ref.read(backendClientProvider), draft);
    } on FormatException catch (error) {
      preparationError = error.message;
    } catch (_) {
      preparationError =
          'No se pudo preparar el cambio con estos datos. Actualiza e inténtalo de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = operation?.status;
    final saving = status == SaveStatus.saving;
    final before = widget.document.summary.accounts;
    final after = operation == null
        ? before
        : FinanceDocument.fromJson(draft.fields).summary.accounts;
    final changes = <Widget>[];
    for (final account in after) {
      final old = before.where((a) => a.id == account.id);
      if (old.isEmpty || old.first.balance != account.balance) {
        changes.add(Text(
            '${account.name}: ${old.isEmpty ? "cuenta nueva" : cop(old.first.balance)} → ${cop(account.balance)}'));
      }
    }
    final oldRows = widget.document.fields['exp'] as List;
    final newRows = operation == null ? oldRows : draft.fields['exp'] as List;
    for (final row in newRows.cast<Map>()) {
      final old = oldRows.cast<Map>().where((e) => e['id'] == row['id']);
      if (old.isEmpty ||
          old.first['paid'] != row['paid'] ||
          old.first['m'] != row['m'] ||
          old.first['amt'] != row['amt'] ||
          old.first['acc'] != row['acc']) {
        changes.add(Text(
            '${row["name"]} · ${row["m"]} · ${cop(row["amt"] as num)} · ${row["paid"] == true ? "Pagado" : "Pendiente"}'));
        final linked = after.where((a) => a.id == row['acc']);
        changes.add(Text(linked.isEmpty
            ? 'Sin cuenta: el pago no cambia ningún saldo.'
            : 'Cuenta: ${linked.first.name}'));
      }
    }
    for (final row in oldRows.cast<Map>()) {
      if (!newRows.cast<Map>().any((e) => e['id'] == row['id'])) {
        changes.add(Text(
            'Eliminar: ${row["name"]} · ${row["m"]} · ${cop(row["amt"] as num)}'));
      }
    }
    return PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            if (preparationError != null) Text(preparationError!),
            if (operation != null) ...[
              const Text(
                  'Revisa el impacto antes de confirmar. Cancelar conserva tus datos.'),
              const SizedBox(height: 16),
              ...changes,
              if (changes.isEmpty)
                const Text(
                    'Se actualizará la configuración indicada en el título.'),
              const SizedBox(height: 24),
              if (status == SaveStatus.review) ...[
                FilledButton(
                    onPressed: () async {
                      final future = operation!.confirm();
                      setState(() {});
                      await future;
                      if (!mounted) return;
                      setState(() {});
                      if (operation!.status == SaveStatus.saved) {
                        ref.invalidate(financeStateProvider);
                      }
                    },
                    child: const Text('Confirmar y guardar')),
                TextButton(
                    onPressed: () {
                      operation!.cancel();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancelar')),
              ] else ...[
                if (saving) const LinearProgressIndicator(),
                Semantics(
                    liveRegion: true,
                    child: Text(switch (status) {
                      SaveStatus.saved =>
                        'Cambio guardado y datos actualizados.',
                      SaveStatus.conflict =>
                        'Los datos cambiaron en otro dispositivo. Recarga y revisa antes de preparar otra operación.',
                      SaveStatus.uncertain =>
                        'Resultado incierto. El servidor podría haber guardado el cambio. Recarga y comprueba el pago antes de repetirlo.',
                      SaveStatus.sessionChanged =>
                        'La sesión cambió. Este borrador no se enviará con otra cuenta.',
                      SaveStatus.rejected =>
                        'El servidor rechazó el cambio. Recarga y revisa los datos y permisos.',
                      _ => 'Guardando…',
                    })),
                if (!saving)
                  FilledButton(
                      onPressed: () {
                        ref.invalidate(financeStateProvider);
                        Navigator.pop(context);
                      },
                      child: const Text('Volver y actualizar')),
              ],
            ],
          ])),
        ));
  }
}
