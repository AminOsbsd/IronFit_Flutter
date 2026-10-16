import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/module.dart';

/// Écran CRUD générique : liste + recherche + ajout / modification / suppression.
class CrudPage extends StatefulWidget {
  final Module module;
  const CrudPage(this.module, {super.key});
  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String q = '';

  Module get m => widget.module;
  bool get canWrite => m.write.contains(Api.role);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load([bool silent = false]) async {
    if (!silent) setState(() { loading = true; error = null; });
    try {
      await Refs.load();
      var l = await Api.list(m.endpoint);
      if (m.filter != null) l = l.where(m.filter!).toList();
      items = l;
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => FormSheet(m, item),
    );
    if (ok == true) load(true);
  }

  Future<void> remove(Map<String, dynamic> x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Supprimer ${m.singular} ?'),
        content: Text(m.titleOf(x)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.call('DELETE', '${m.endpoint}/${x['id']}');
      load(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ql = q.toLowerCase();
    final shown = items.where((x) => '${m.titleOf(x)} ${m.subtitleOf(x)}'.toLowerCase().contains(ql)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(m.title), actions: [IconButton(onPressed: () => load(), icon: const Icon(Icons.refresh))]),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Ajouter'))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher…', border: OutlineInputBorder(), isDense: true),
            onChanged: (s) => setState(() => q = s),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: () => load(), child: const Text('Réessayer')),
                        ]),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => load(true),
                      child: shown.isEmpty
                          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), Center(child: Text('Aucun élément'))])
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                              itemCount: shown.length,
                              itemBuilder: (c, i) {
                                final x = shown[i];
                                final act = m.action?.call(c, x, () => load(true));
                                return Card(
                                  child: ListTile(
                                    title: Text(m.titleOf(x)),
                                    subtitle: Text(m.subtitleOf(x)),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      if (act != null) act,
                                      if (canWrite)
                                        PopupMenuButton<String>(
                                          onSelected: (v) => v == 'e' ? edit(x) : remove(x),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'e', child: Text('Modifier')),
                                            PopupMenuItem(value: 'd', child: Text('Supprimer')),
                                          ],
                                        ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ]),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String todayStr() {
  final n = DateTime.now();
  return '${n.year}-${_two(n.month)}-${_two(n.day)}';
}

class FormSheet extends StatefulWidget {
  final Module m;
  final Map<String, dynamic>? item;
  const FormSheet(this.m, this.item, {super.key});
  @override
  State<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<FormSheet> {
  final formKey = GlobalKey<FormState>();
  final Map<String, dynamic> v = {};
  String? err;
  bool busy = false;

  Module get m => widget.m;
  Map<String, dynamic>? get item => widget.item;

  @override
  void initState() {
    super.initState();
    for (final f in m.fields) {
      if (f.type == FT.password) continue;
      dynamic x = item?[f.key];
      if (x == null && item == null && f.today) x = todayStr();
      v[f.key] = x;
    }
  }

  Widget field(Field f) {
    final label = f.label + (f.required ? ' *' : '');
    switch (f.type) {
      case FT.select:
        final o = f.options ?? Refs.options(f.ref!);
        final Object? cur = o.containsKey(v[f.key]) ? v[f.key] as Object? : null;
        return DropdownButtonFormField<Object?>(
          value: cur,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<Object?>(value: null, child: Text('—')),
            for (final e in o.entries) DropdownMenuItem<Object?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: (x) => v[f.key] = x,
          validator: (x) => f.required && x == null ? 'Obligatoire' : null,
        );
      case FT.date:
      case FT.time:
        return _Picker(label: label, time: f.type == FT.time, value: v[f.key]?.toString(), required: f.required, onChanged: (s) => v[f.key] = s);
      default:
        final pw = f.type == FT.password;
        return TextFormField(
          initialValue: pw ? '' : (v[f.key]?.toString() ?? ''),
          obscureText: pw,
          maxLines: f.type == FT.multiline ? 3 : 1,
          keyboardType: f.type == FT.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : f.type == FT.email ? TextInputType.emailAddress : f.type == FT.phone ? TextInputType.phone : null,
          decoration: InputDecoration(labelText: label, helperText: pw && item != null ? 'Laisser vide = inchangé' : null),
          onChanged: (s) => v[f.key] = s,
          validator: (s) {
            s = (s ?? '').trim();
            if (f.required && s.isEmpty) return 'Obligatoire';
            if (pw) {
              if (item == null && s.isEmpty) return 'Obligatoire';
              if (s.isNotEmpty && s.length < 6) return '6 caractères minimum';
            }
            if (f.type == FT.number && s.isNotEmpty && double.tryParse(s.replaceAll(',', '.')) == null) return 'Nombre invalide';
            return null;
          },
        );
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { busy = true; err = null; });
    final body = <String, dynamic>{...m.extra};
    for (final f in m.fields) {
      dynamic x = v[f.key];
      if (x is String) {
        x = x.trim();
        if (f.type == FT.number) x = x.replaceAll(',', '.');
        if (x == '') x = null;
      }
      if (f.type == FT.password && x == null) continue;
      body[f.key] = x;
    }
    try {
      await Api.call(item == null ? 'POST' : 'PUT', item == null ? m.endpoint : '${m.endpoint}/${item!['id']}', body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { err = '$e'; busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${item == null ? "Ajouter" : "Modifier"} ${m.singular}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final f in m.fields) Padding(padding: const EdgeInsets.only(top: 8), child: field(f)),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Annuler'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: busy ? null : save, child: Text(busy ? '…' : 'Enregistrer'))),
            ]),
          ]),
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
  const _Picker({required this.label, required this.time, required this.value, required this.required, required this.onChanged});
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final TextEditingController c = TextEditingController(text: widget.value ?? '');

  Future<void> pick() async {
    String? r;
    if (widget.time) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (t != null) r = '${_two(t.hour)}:${_two(t.minute)}';
    } else {
      final d = await showDatePicker(
        context: context, initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
        firstDate: DateTime(2020), lastDate: DateTime(2100),
      );
      if (d != null) r = '${d.year}-${_two(d.month)}-${_two(d.day)}';
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
        decoration: InputDecoration(labelText: widget.label, suffixIcon: Icon(widget.time ? Icons.access_time : Icons.calendar_today)),
        validator: (s) => widget.required && (s ?? '').isEmpty ? 'Obligatoire' : null,
      );

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
}
