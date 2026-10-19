import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';

/// Notifications personnelles (abonnement, coaching, programmes, annonces…).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with AsyncLoadMixin<NotificationsPage, List<Json>> {
  @override
  Future<List<Json>> fetch() async {
    final r = await Api.get(Api.withQuery('notifications', {'limit': 100}));
    Api.unread.value = (r['unread'] as int?) ?? 0;
    return jsonList(r, 'items');
  }

  Future<void> read(Json n) async {
    if (n['seen'] == 1) return;
    try {
      await Api.call('POST', 'notifications/${n['id']}/read');
    } on ApiException {
      return; // sans conséquence : la notification reste simplement non lue
    }
    if (!mounted) return; // l'utilisateur a pu quitter l'écran pendant la requête
    setState(() => n['seen'] = 1);
    Api.unread.value = (Api.unread.value - 1).clamp(0, 1 << 30);
  }

  Future<void> readAll() async {
    if (await attempt(context, () => Api.call('POST', 'notifications/read-all'))) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = data ?? const <Json>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (items.any((n) => n['seen'] == 0)) TextButton(onPressed: readAll, child: const Text('Tout lire'))],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, items) => RefreshIndicator(
          onRefresh: reload,
          child: items.isEmpty
              ? const ScrollableEmptyState(
                  child: EmptyState(icon: Icons.notifications_none, text: 'Aucune notification'),
                )
              : ListView.builder(
                  padding: Gaps.page,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final n = items[i], unseen = n['seen'] == 0;
                    final body = n['body'] == null ? '' : '${n['body']}\n';
                    return Card(
                      color: unseen ? cs.primaryContainer : null,
                      child: Semantics(
                        label: unseen ? 'Non lue' : null,
                        child: ListTile(
                          leading: Icon(unseen ? Icons.circle_notifications : Icons.notifications_none),
                          title: Text(
                            '${n['title']}',
                            style: TextStyle(fontWeight: unseen ? FontWeight.bold : FontWeight.normal),
                          ),
                          subtitle: Text('$body${localStamp(n['created'])}'),
                          isThreeLine: n['body'] != null,
                          onTap: () => read(n),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
