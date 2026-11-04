import 'package:flutter/material.dart';

class InputSpec {
  const InputSpec(this.key, this.label,
      {this.initial = '',
      this.options,
      this.numeric = false,
      this.required = true});
  final String key, label, initial;
  final Map<String, String>? options;
  final bool numeric, required;
}

class OperationForm extends StatefulWidget {
  const OperationForm({super.key, required this.title, required this.fields});
  final String title;
  final List<InputSpec> fields;
  @override
  State<OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<OperationForm> {
  final formKey = GlobalKey<FormState>();
  final values = <String, String>{};
  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      values[field.key] = field.initial;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
          child: Form(
              key: formKey,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                ...widget.fields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: field.options == null
                        ? TextFormField(
                            initialValue: field.initial,
                            decoration: InputDecoration(labelText: field.label),
                            keyboardType: field.numeric
                                ? const TextInputType.numberWithOptions(
                                    decimal: true, signed: true)
                                : TextInputType.text,
                            onChanged: (value) => values[field.key] = value,
                            validator: (value) =>
                                field.required && (value ?? '').trim().isEmpty
                                    ? 'Completa este campo.'
                                    : null)
                        : DropdownButtonFormField<String>(
                            initialValue:
                                field.options!.containsKey(field.initial)
                                    ? field.initial
                                    : null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: field.label),
                            items: field.options!.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key, child: Text(e.value)))
                                .toList(),
                            onChanged: (value) => values[field.key] = value ?? '',
                            validator: (value) => field.required && (value ?? '').isEmpty ? 'Selecciona una opción.' : null))),
                FilledButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context, values);
                      }
                    },
                    child: const Text('Revisar impacto')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
              ]))));
}
