import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

/// Notifications personnelles (abonnement, coaching, programmes, annonces…).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Api.get(Api.withQuery('notifications', {'limit': 100}));
      items = (r['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      Api.unread.value = (r['unread'] ?? 0) as int;
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> read(Map<String, dynamic> n) async {
    if (n['seen'] == 1) return;
    try {
      await Api.call('POST', 'notifications/${n['id']}/read');
      setState(() => n['seen'] = 1);
      Api.unread.value = (Api.unread.value - 1).clamp(0, 1 << 30);
    } catch (_) {}
  }

  Future<void> readAll() async {
    if (await attempt(context, () => Api.call('POST', 'notifications/read-all'))) load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        if (items.any((n) => n['seen'] == 0)) TextButton(onPressed: readAll, child: const Text('Tout lire')),
      ]),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: items.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 80), Empty(Icons.notifications_none, 'Aucune notification')])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final n = items[i], unseen = n['seen'] == 0;
                    return Card(
                      color: unseen ? cs.primaryContainer : null,
                      child: ListTile(
                        leading: Icon(unseen ? Icons.circle_notifications : Icons.notifications_none),
                        title: Text('${n['title']}', style: TextStyle(fontWeight: unseen ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text('${n['body'] ?? ''}${n['body'] == null ? '' : '\n'}${localStamp(n['created'])}'),
                        isThreeLine: n['body'] != null,
                        onTap: () => read(n),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
