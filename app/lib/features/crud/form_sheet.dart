import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/api/refs.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/feedback.dart';
import 'module.dart';

bool isEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

/// Validation d'un champ texte de module. Renvoie le message d'erreur, ou `null` si valide.
String? validateField(Field f, String? input, {required bool creating}) {
  final s = (input ?? '').trim();
  if (f.required && s.isEmpty) return 'Obligatoire';
  if (f.type == FieldType.password) {
    if (creating && s.isEmpty) return 'Obligatoire';
    if (s.isNotEmpty && s.length < 6) return '6 caractères minimum';
  }
  if (f.type == FieldType.email && s.isNotEmpty && !isEmail(s)) return 'E-mail invalide';
  if (f.type == FieldType.number && s.isNotEmpty) {
    final n = double.tryParse(s.replaceAll(',', '.'));
    if (n == null) return 'Nombre invalide';
    if (n < 0) return 'Doit être positif';
  }
  return null;
}

/// Corps de requête à partir des valeurs saisies pour les champs [fields] : textes nettoyés, virgule décimale,
/// vides → `null`, mot de passe vide omis (= inchangé).
Json buildBody(List<Field> fields, Map<String, Object?> values) {
  final body = <String, dynamic>{};
  for (final f in fields) {
    var x = values[f.key];
    if (x is String) {
      var s = x.trim();
      if (f.type == FieldType.number) s = s.replaceAll(',', '.');
      x = s.isEmpty ? null : s;
    }
    if (f.type == FieldType.password && x == null) continue;
    body[f.key] = x;
  }
  return body;
}

/// Formulaire d'ajout / modification d'un élément de module (feuille modale).
class FormSheet extends StatefulWidget {
  final Module m;
  final Json? item;
  const FormSheet(this.m, this.item, {super.key});

  @override
  State<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<FormSheet> {
  final formKey = GlobalKey<FormState>();
  final Map<String, Object?> v = {};
  String? err;
  bool busy = false;

  Module get m => widget.m;
  Json? get item => widget.item;
  List<Field> get fields => m.fields.where((f) => f.visible).toList();

  @override
  void initState() {
    super.initState();
    for (final f in fields) {
      if (f.type == FieldType.password) continue;
      Object? x = item?[f.key];
      if (x == null && item == null) x = f.today ? todayIso() : f.initial;
      v[f.key] = x;
    }
  }

  Widget field(Field f) {
    final label = f.label + (f.required ? ' *' : '');
    switch (f.type) {
      case FieldType.select:
        final o = f.options ?? Refs.options(f.ref!);
        final cur = o.containsKey(v[f.key]) ? v[f.key] : null;
        return DropdownButtonFormField<Object?>(
          initialValue: cur,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            if (!f.required) const DropdownMenuItem<Object?>(child: Text('—')),
            for (final e in o.entries) DropdownMenuItem<Object?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: (x) => v[f.key] = x,
          validator: (x) => f.required && x == null ? 'Obligatoire' : null,
        );
      case FieldType.date:
      case FieldType.time:
        return _Picker(
          label: label,
          time: f.type == FieldType.time,
          value: v[f.key]?.toString(),
          required: f.required,
          onChanged: (s) => v[f.key] = s,
        );
      default:
        final pw = f.type == FieldType.password;
        return TextFormField(
          initialValue: pw ? '' : (v[f.key]?.toString() ?? ''),
          obscureText: pw,
          autocorrect: !pw,
          maxLines: f.type == FieldType.multiline ? 3 : 1,
          keyboardType: switch (f.type) {
            FieldType.number => const TextInputType.numberWithOptions(decimal: true),
            FieldType.email => TextInputType.emailAddress,
            FieldType.phone => TextInputType.phone,
            FieldType.multiline => TextInputType.multiline,
            _ => null,
          },
          decoration: InputDecoration(
            labelText: label,
            helperText: pw && item != null ? 'Laisser vide = inchangé' : null,
          ),
          onChanged: (s) => v[f.key] = s,
          validator: (s) => validateField(f, s, creating: item == null),
        );
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      err = null;
    });
    final item = this.item;
    try {
      await Api.call(
        item == null ? 'POST' : 'PUT',
        item == null ? m.endpoint : '${m.endpoint}/${item['id']}',
        buildBody(fields, v),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          err = '$e';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, MediaQuery.viewInsetsOf(context).bottom + Gaps.lg),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '${item == null ? 'Ajouter' : 'Modifier'} ${m.singular}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Gaps.h8,
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(top: Gaps.md),
                  child: field(f),
                ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gaps.md),
                  child: StatusMessage(err!),
                ),
              Gaps.h16,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                  ),
                  Gaps.w12,
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : save,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Enregistrement'),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Picker extends StatefulWidget {
  final String label;
  final bool time, required;
  final String? value;
  final ValueChanged<String> onChanged;

  const _Picker({
    required this.label,
    required this.time,
    required this.value,
    required this.required,
    required this.onChanged,
  });

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final TextEditingController c = TextEditingController(text: widget.value ?? '');

  Future<void> pick() async {
    String? r;
    if (widget.time) {
      final parts = c.text.split(':');
      final initial = parts.length == 2
          ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0)
          : TimeOfDay.now();
      final t = await showTimePicker(context: context, initialTime: initial);
      if (t != null) r = '${twoDigits(t.hour)}:${twoDigits(t.minute)}';
    } else {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (d != null) r = isoDate(d);
    }
    if (r != null) {
      c.text = r;
      widget.onChanged(r);
    }
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: c,
    readOnly: true,
    onTap: pick,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: Icon(widget.time ? Icons.access_time : Icons.calendar_today),
    ),
    validator: (s) => widget.required && (s ?? '').isEmpty ? 'Obligatoire' : null,
  );

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
}
