import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../notifications/notifications_page.dart';

/// Cloche des notifications avec pastille du nombre de non lues.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    Api.refreshUnread();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: Api.unread,
    builder: (_, n, _) => IconButton(
      tooltip: n > 0 ? 'Notifications, $n non lue${n > 1 ? 's' : ''}' : 'Notifications',
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: Icon(n > 0 ? Icons.notifications_active : Icons.notifications_none),
      ),
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));
        await Api.refreshUnread();
      },
    ),
  );
}
