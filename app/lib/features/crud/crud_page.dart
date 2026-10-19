import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/api/refs.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import 'form_sheet.dart';
import 'module.dart';

/// Écran CRUD générique : liste paginée + recherche côté serveur + ajout / modification / suppression.
class CrudPage extends StatefulWidget {
  final Module module;
  const CrudPage(this.module, {super.key});

  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> with AsyncLoadMixin<CrudPage, List<Json>> {
  static const pageSize = 50;
  bool more = false, loadingMore = false;
  String q = '';
  Timer? _debounce;

  Module get m => widget.module;
  bool get canWrite => m.canWrite(Api.role);
  bool canEdit(Json x) => canWrite && (m.canEditRow?.call(x) ?? true);

  String endpoint(int offset) =>
      Api.withQuery(m.endpoint, {...?m.query?.call(), 'q': q.trim(), 'limit': pageSize, 'offset': offset});

  @override
  Future<List<Json>> fetch() async {
    final (_, l) = await (Refs.load(), Api.list(endpoint(0))).wait;
    more = l.length == pageSize;
    return l;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> loadMore() async {
    setState(() => loadingMore = true);
    try {
      final l = await Api.list(endpoint(data?.length ?? 0));
      if (!mounted) return;
      setState(() {
        data = [...?data, ...l];
        more = l.length == pageSize;
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, '$e');
    }
    if (mounted) setState(() => loadingMore = false);
  }

  void search(String s) {
    q = s;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), reload);
  }

  Future<void> edit([Json? item]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FormSheet(m, item),
    );
    if (ok ?? false) await reload();
  }

  Future<void> remove(Json x) async {
    if (!await confirm(context, 'Supprimer ${m.singular} ?', body: m.titleOf(x), ok: 'Supprimer')) return;
    if (!mounted) return;
    if (await attempt(context, () => Api.call('DELETE', '${m.endpoint}/${x['id']}'))) await reload();
  }

  Widget tile(BuildContext c, Json x) {
    final act = m.action?.call(c, x, reload);
    final extra = m.menu?.call(x) ?? const <RowMenu>[];
    final editable = canEdit(x);
    final badge = m.badge?.call(x);
    final title = m.titleOf(x);
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(m.subtitleOf(x)),
        onTap: editable ? () => edit(x) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?badge,
            ?act,
            if (editable || (canWrite && extra.isNotEmpty))
              PopupMenuButton<Object>(
                tooltip: 'Actions pour $title',
                onSelected: (v) async {
                  if (v == 'e') return edit(x);
                  if (v == 'd') return remove(x);
                  if (v is RowMenu && await attempt(context, () => v.run(context, x))) await reload();
                },
                itemBuilder: (_) => [
                  if (editable)
                    const PopupMenuItem(
                      value: 'e',
                      child: ListTile(leading: Icon(Icons.edit), title: Text('Modifier')),
                    ),
                  for (final r in extra)
                    PopupMenuItem(
                      value: r,
                      child: ListTile(leading: Icon(r.icon), title: Text(r.label)),
                    ),
                  if (editable)
                    const PopupMenuItem(
                      value: 'd',
                      child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Supprimer')),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(m.title),
        actions: [RefreshButton(onPressed: reload)],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(onPressed: edit, icon: const Icon(Icons.add), label: const Text('Ajouter'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.sm, Gaps.md, Gaps.xs),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Rechercher', isDense: true),
              onChanged: search,
            ),
          ),
          Expanded(
            child: AsyncStateView(
              loading: loading,
              error: error,
              data: data,
              onRetry: reload,
              builder: (context, items) => RefreshIndicator(
                onRefresh: reload,
                child: items.isEmpty
                    ? ScrollableEmptyState(
                        child: EmptyState(
                          icon: m.icon,
                          text: q.isEmpty ? 'Aucun élément' : 'Aucun résultat pour « $q »',
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.xs, Gaps.md, 88),
                        itemCount: items.length + (more ? 1 : 0),
                        itemBuilder: (c, i) => i < items.length
                            ? tile(c, items[i])
                            : Padding(
                                padding: const EdgeInsets.all(Gaps.sm),
                                child: Center(
                                  child: loadingMore
                                      ? const CircularProgressIndicator(semanticsLabel: 'Chargement')
                                      : OutlinedButton.icon(
                                          onPressed: loadMore,
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text('Charger plus'),
                                        ),
                                ),
                              ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
