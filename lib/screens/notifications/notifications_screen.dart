import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/notification_provider.dart';
import '../../widgets/common_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load(refresh: true);
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<NotificationProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => provider.markAllRead(),
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: items.isEmpty && provider.loading
          ? const ShimmerList()
          : items.isEmpty
              ? const EmptyWidget(message: 'No notifications', icon: Icons.notifications_none)
              : RefreshIndicator(
                  onRefresh: () => provider.load(refresh: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: items.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final n = items[i];
                      return Dismissible(
                        key: Key('notif_${n.id}'),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          color: Colors.green,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                        onDismissed: (_) => provider.markRead(n.id),
                        child: ListTile(
                          tileColor: n.isRead ? null : Colors.blue.withOpacity(0.05),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: n.isRead ? Colors.grey[100] : Colors.blue[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForType(n.type),
                              color: n.isRead ? Colors.grey : Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(n.title,
                              style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text(
                                timeago.format(DateTime.tryParse(n.createdAt) ?? DateTime.now()),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            if (!n.isRead) provider.markRead(n.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ticket': return Icons.support_agent;
      case 'task': return Icons.task;
      case 'invoice': return Icons.receipt;
      case 'lead': return Icons.trending_up;
      default: return Icons.notifications;
    }
  }
}
