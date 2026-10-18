import 'package:flutter/material.dart';
import 'common_widgets.dart';

enum DType { text, multiline, integer, decimal, date, slider }

/// Champ d'une boîte de dialogue de saisie.
class DField {
  final String key, label;
  final DType type;
  final bool required;
  final Object? initial;
  final int min, max; // bornes pour integer / slider
  const DField(this.key, this.label, {this.type = DType.text, this.required = false, this.initial, this.min = 0, this.max = 100000});
}

/// Affiche un formulaire simple et renvoie les valeurs saisies (null si annulé).
/// Si [submit] est fourni, il est appelé avant la fermeture ; une erreur (ex. refus du serveur) s'affiche dans la boîte.
Future<Map<String, dynamic>?> formDialog(BuildContext context, String title, List<DField> fields, {String ok = 'Enregistrer', Future<void> Function(Map<String, dynamic>)? submit}) {
  return showDialog<Map<String, dynamic>>(context: context, builder: (_) => _FormDialog(title, fields, ok, submit));
}

class _FormDialog extends StatefulWidget {
  final String title, ok;
  final List<DField> fields;
  final Future<void> Function(Map<String, dynamic>)? submit;
  const _FormDialog(this.title, this.fields, this.ok, this.submit);
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final formKey = GlobalKey<FormState>();
  final Map<String, dynamic> v = {};
  final Map<String, TextEditingController> c = {};
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      v[f.key] = f.initial ?? (f.type == DType.date ? todayIso() : (f.type == DType.slider ? f.min : null));
      if (f.type != DType.slider) c[f.key] = TextEditingController(text: v[f.key] == null ? '' : '${v[f.key]}');
    }
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.type == DType.slider) {
        out[f.key] = v[f.key];
        continue;
      }
      final s = c[f.key]!.text.trim();
      out[f.key] = s.isEmpty
          ? null
          : switch (f.type) {
              DType.integer => int.parse(s),
              DType.decimal => double.parse(s.replaceAll(',', '.')),
              _ => s,
            };
    }
    if (widget.submit != null) {
      setState(() { busy = true; err = null; });
      try {
        await widget.submit!(out);
      } catch (e) {
        if (mounted) setState(() { busy = false; err = '$e'; });
        return;
      }
    }
    if (mounted) Navigator.pop(context, out);
  }

  Widget field(DField f) {
    final label = f.label + (f.required ? ' *' : '');
    if (f.type == DType.slider) {
      return StatefulBuilder(
        builder: (_, set) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label : ${v[f.key]}/${f.max}'),
          Slider(value: (v[f.key] as int).toDouble(), min: f.min.toDouble(), max: f.max.toDouble(), divisions: f.max - f.min, label: '${v[f.key]}', onChanged: (x) => set(() => v[f.key] = x.round())),
        ]),
      );
    }
    if (f.type == DType.date) {
      return TextFormField(
        controller: c[f.key],
        readOnly: true,
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today)),
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(c[f.key]!.text) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
          if (d != null) c[f.key]!.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        },
        validator: (s) => f.required && (s ?? '').isEmpty ? 'Obligatoire' : null,
      );
    }
    final numeric = f.type == DType.integer || f.type == DType.decimal;
    return TextFormField(
      controller: c[f.key],
      maxLines: f.type == DType.multiline ? 3 : 1,
      keyboardType: numeric ? TextInputType.numberWithOptions(decimal: f.type == DType.decimal) : null,
      decoration: InputDecoration(labelText: label),
      validator: (s) {
        s = (s ?? '').trim();
        if (s.isEmpty) return f.required ? 'Obligatoire' : null;
        if (f.type == DType.integer) {
          final n = int.tryParse(s);
          if (n == null) return 'Nombre entier attendu';
          if (n < f.min || n > f.max) return 'Entre ${f.min} et ${f.max}';
        }
        if (f.type == DType.decimal) {
          final n = double.tryParse(s.replaceAll(',', '.'));
          if (n == null) return 'Nombre invalide';
          if (n < f.min || n > f.max) return 'Entre ${f.min} et ${f.max}';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 8), child: field(f)),
                if (err != null) Text(err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: busy ? null : save, child: Text(widget.ok)),
        ],
      );
}
