import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart' show Json;
import '../widgets/common_widgets.dart';

/// Notifications personnelles (abonnement, coaching, programmes, annonces…).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Json> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      items = await NotificationService.load();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> read(Json n) async {
    if (isTrue(n['seen'])) return;
    try {
      await NotificationService.markRead(n['id'] as int);
      setState(() => n['seen'] = true);
    } catch (_) {}
  }

  Future<void> readAll() async {
    if (await attempt(context, NotificationService.markAllRead)) load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        if (items.any((n) => !isTrue(n['seen']))) TextButton.icon(onPressed: readAll, icon: const Icon(Icons.done_all_rounded), label: const Text('Tout lire')),
      ]),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: items.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 80), Empty(Icons.notifications_none_rounded, 'Aucune notification')])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final n = items[i], unseen = !isTrue(n['seen']);
                    return Card(
                      color: unseen ? cs.primaryContainer.withValues(alpha: 0.55) : null,
                      child: ListTile(
                        leading: IconBadge(unseen ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: unseen ? AppColors.ember : null),
                        title: Text('${n['title']}', style: TextStyle(fontWeight: unseen ? FontWeight.w800 : FontWeight.w500)),
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
