import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../services/catalog_service.dart';
import '../models/module.dart';
import '../widgets/common_widgets.dart';

/// Écran CRUD générique : liste paginée + recherche côté serveur + ajout / modification / suppression.
class CrudPage extends StatefulWidget {
  final Module module;
  const CrudPage(this.module, {super.key});
  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> {
  static const pageSize = 50;
  List<Map<String, dynamic>> items = [];
  bool loading = true, more = false, loadingMore = false;
  String? error;
  String q = '';
  Timer? _debounce;

  Module get m => widget.module;
  bool get canWrite => m.write.contains(Api.role);
  bool canEdit(Map<String, dynamic> x) => canWrite && (m.canEditRow?.call(x) ?? true);

  Future<List<Map<String, dynamic>>> page(int offset) => CrudService.list(m.endpoint, {...?m.query?.call(), 'q': q.trim(), 'limit': pageSize, 'offset': offset});

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> load([bool silent = false]) async {
    if (!silent) setState(() { loading = true; error = null; });
    try {
      await Refs.load();
      final l = await page(0);
      items = l;
      more = l.length == pageSize;
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadMore() async {
    setState(() => loadingMore = true);
    try {
      final l = await page(items.length);
      items = [...items, ...l];
      more = l.length == pageSize;
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => loadingMore = false);
  }

  void search(String s) {
    q = s;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => load(true));
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => FormSheet(m, item),
    );
    if (ok == true) load(true);
  }

  Future<void> remove(Map<String, dynamic> x) async {
    if (!await confirm(context, 'Supprimer ${m.singular} ?', body: m.titleOf(x), ok: 'Supprimer')) return;
    if (!mounted) return;
    if (await attempt(context, () => CrudService.delete(m.endpoint, x['id'] as Object))) load(true);
  }

  Widget tile(BuildContext c, Map<String, dynamic> x) {
    final act = m.action?.call(c, x, () => load(true));
    final extra = m.menu?.call(x) ?? const <RowMenu>[];
    final editable = canEdit(x);
    final badge = m.badge?.call(x);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        leading: IconBadge(m.icon),
        title: Text(m.titleOf(x)),
        subtitle: Text(m.subtitleOf(x)),
        onTap: editable ? () => edit(x) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ?badge,
          ?act,
          if (editable || (canWrite && extra.isNotEmpty))
            PopupMenuButton<Object>(
              onSelected: (v) async {
                if (v == 'e') return edit(x);
                if (v == 'd') return remove(x);
                if (v is RowMenu && await attempt(context, () => v.run(context, x))) load(true);
              },
              itemBuilder: (_) => [
                if (editable) const PopupMenuItem(value: 'e', child: ListTile(leading: Icon(Icons.edit), title: Text('Modifier'))),
                for (final r in extra) PopupMenuItem(value: r, child: ListTile(leading: Icon(r.icon), title: Text(r.label))),
                if (editable) const PopupMenuItem(value: 'd', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Supprimer'))),
              ],
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(m.title), actions: [IconButton(tooltip: 'Actualiser', onPressed: () => load(), icon: const Icon(Icons.refresh))]),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Ajouter'))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher…', border: OutlineInputBorder(), isDense: true),
            onChanged: search,
          ),
        ),
        Expanded(
          child: AsyncBody(
            loading: loading,
            error: error,
            onRetry: load,
            builder: () => RefreshIndicator(
              onRefresh: () => load(true),
              child: items.isEmpty
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                      const SizedBox(height: 60),
                      Empty(m.icon, q.isEmpty ? 'Aucun élément' : 'Aucun résultat pour « $q »'),
                    ])
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                      itemCount: items.length + (more ? 1 : 0),
                      itemBuilder: (c, i) => i < items.length
                          ? tile(c, items[i])
                          : Padding(
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: loadingMore ? const CircularProgressIndicator() : OutlinedButton.icon(onPressed: loadMore, icon: const Icon(Icons.expand_more), label: const Text('Charger plus')),
                              ),
                            ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

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
  List<Field> get fields => m.fields.where((f) => f.visible).toList();

  @override
  void initState() {
    super.initState();
    for (final f in fields) {
      if (f.type == FT.password) continue;
      dynamic x = item?[f.key];
      if (x == null && item == null) x = f.today ? todayIso() : f.initial;
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
          initialValue: cur,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            if (!f.required) const DropdownMenuItem<Object?>(value: null, child: Text('—')),
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
            if (f.type == FT.email && s.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'E-mail invalide';
            if (f.type == FT.number && s.isNotEmpty) {
              final n = double.tryParse(s.replaceAll(',', '.'));
              if (n == null) return 'Nombre invalide';
              if (n < 0) return 'Doit être positif';
            }
            return null;
          },
        );
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { busy = true; err = null; });
    final body = <String, dynamic>{};
    for (final f in fields) {
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
      item == null ? await CrudService.create(m.endpoint, body) : await CrudService.update(m.endpoint, item!['id'] as Object, body);
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
            for (final f in fields) Padding(padding: const EdgeInsets.only(top: 8), child: field(f)),
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
