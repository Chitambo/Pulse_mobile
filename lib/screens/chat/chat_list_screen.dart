import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../models/chat.dart';
import '../../core/api/api_constants.dart';

/// Full replacement for the chat channel list screen.
/// Changes vs old version:
///  - ChannelTile shows a notification-level icon (🔕 muted, 💬 mentions, ⚡ priority)
///  - Long-press on a tile opens a bottom sheet to change the notification level
///  - AppBar has a moon (🌙) action that opens a DND settings bottom sheet
class ChatListScreen extends StatefulWidget {
  final Dio dio;
  final int myUserId;
  final void Function(ChatChannel channel) onChannelTap;

  const ChatListScreen({
    Key? key,
    required this.dio,
    required this.myUserId,
    required this.onChannelTap,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatChannel> _channels = [];
  bool _loading = true;
  NotificationPreference _dnd = NotificationPreference.defaults();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadChannels(), _loadDnd()]);
  }

  Future<void> _loadChannels() async {
    try {
      final res = await widget.dio.get(ApiConstants.chatChannels);
      final list = (res.data as List).map((j) => ChatChannel.fromJson(j)).toList();
      if (mounted) setState(() { _channels = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDnd() async {
    try {
      final res = await widget.dio.get(ApiConstants.chatNotificationPreferences);
      if (mounted) setState(() => _dnd = NotificationPreference.fromJson(res.data));
    } catch (_) {}
  }

  Future<void> _setNotificationLevel(ChatChannel ch, String level) async {
    try {
      await widget.dio.put(
        ApiConstants.channelNotificationLevel(ch.id),
        data: {'level': level},
      );
      setState(() {
        final idx = _channels.indexWhere((c) => c.id == ch.id);
        if (idx != -1) {
          _channels[idx] = ChatChannel(
            id: ch.id,
            name: ch.name,
            type: ch.type,
            description: ch.description,
            lastMessage: ch.lastMessage,
            unreadCount: ch.unreadCount,
            members: ch.members,
            notificationLevel: level,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update notification level')),
        );
      }
    }
  }

  Future<void> _saveDnd(NotificationPreference pref) async {
    try {
      await widget.dio.put(ApiConstants.chatNotificationPreferences, data: {
        'dndEnabled': pref.dndEnabled,
        'dndStart': pref.dndStart,
        'dndEnd': pref.dndEnd,
      });
      if (mounted) setState(() => _dnd = pref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save DND settings')),
        );
      }
    }
  }

  void _showNotificationLevelSheet(ChatChannel ch) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NotificationLevelSheet(
        channel: ch,
        myUserId: widget.myUserId,
        current: ch.notificationLevel,
        onSelect: (level) {
          Navigator.pop(context);
          _setNotificationLevel(ch, level);
        },
      ),
    );
  }

  void _showDndSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DndSheet(
        initial: _dnd,
        onSave: (pref) {
          Navigator.pop(context);
          _saveDnd(pref);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Do Not Disturb',
            icon: Icon(
              _dnd.isActiveNow ? Icons.bedtime : Icons.bedtime_outlined,
              color: _dnd.isActiveNow ? Colors.indigo : null,
            ),
            onPressed: _showDndSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: _channels.isEmpty
                  ? const Center(child: Text('No channels yet'))
                  : ListView.builder(
                      itemCount: _channels.length,
                      itemBuilder: (ctx, i) => _ChannelTile(
                        channel: _channels[i],
                        myUserId: widget.myUserId,
                        onTap: () => widget.onChannelTap(_channels[i]),
                        onLongPress: () => _showNotificationLevelSheet(_channels[i]),
                      ),
                    ),
            ),
    );
  }
}

// ── Channel Tile ──────────────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  final ChatChannel channel;
  final int myUserId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChannelTile({
    required this.channel,
    required this.myUserId,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDm = channel.type == 'dm';
    final displayName = channel.displayName(myUserId);
    final lastMsg = channel.lastMessage;
    final levelIcon = _notifIcon(channel.notificationLevel);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: isDm ? Colors.teal.shade100 : Colors.indigo.shade100,
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(
            color: isDm ? Colors.teal.shade700 : Colors.indigo.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (levelIcon != null) ...[
            const SizedBox(width: 4),
            Icon(levelIcon.icon, size: 14, color: levelIcon.color),
          ],
          if (channel.unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${channel.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: lastMsg != null
          ? Text(
              lastMsg.isDeleted ? 'Message deleted' : _previewText(lastMsg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            )
          : null,
    );
  }

  String _previewText(ChatMessage msg) {
    if (msg.type == 'file') return '📎 ${msg.fileName ?? 'File'}';
    return msg.content;
  }

  _IconData? _notifIcon(String level) {
    switch (level) {
      case 'muted':
        return _IconData(Icons.notifications_off, Colors.grey);
      case 'mentions':
        return _IconData(Icons.alternate_email, Colors.blue.shade600);
      case 'priority':
        return _IconData(Icons.bolt, Colors.orange.shade700);
      default:
        return null; // 'all' — no icon needed
    }
  }
}

class _IconData {
  final IconData icon;
  final Color color;
  const _IconData(this.icon, this.color);
}

// ── Notification Level Bottom Sheet ──────────────────────────────────────────

class _NotificationLevelSheet extends StatelessWidget {
  final ChatChannel channel;
  final int myUserId;
  final String current;
  final void Function(String level) onSelect;

  const _NotificationLevelSheet({
    required this.channel,
    required this.myUserId,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final channelName = channel.displayName(myUserId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications — $channelName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Long-press a channel anytime to change this.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ..._levels.map((l) => _LevelTile(
            icon: l.icon,
            iconColor: l.color,
            title: l.title,
            subtitle: l.subtitle,
            selected: current == l.value,
            onTap: () => onSelect(l.value),
          )),
        ],
      ),
    );
  }

  static const _levels = [
    _Level(
      value: 'all',
      icon: Icons.notifications_active,
      color: Colors.indigo,
      title: 'All messages',
      subtitle: 'Notify for every message',
    ),
    _Level(
      value: 'mentions',
      icon: Icons.alternate_email,
      color: Colors.blue,
      title: 'Mentions only',
      subtitle: 'Only when someone @mentions you',
    ),
    _Level(
      value: 'priority',
      icon: Icons.bolt,
      color: Colors.orange,
      title: 'Priority only',
      subtitle: 'Urgent messages and mentions',
    ),
    _Level(
      value: 'muted',
      icon: Icons.notifications_off,
      color: Colors.grey,
      title: 'Muted',
      subtitle: 'No notifications (unread count still updates)',
    ),
  ];
}

class _Level {
  final String value;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Level({
    required this.value,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _LevelTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LevelTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? iconColor.withOpacity(0.15) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: selected ? iconColor : Colors.grey.shade600),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? iconColor : null,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: selected
          ? Icon(Icons.check_circle, color: iconColor)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ── DND Bottom Sheet ──────────────────────────────────────────────────────────

class _DndSheet extends StatefulWidget {
  final NotificationPreference initial;
  final void Function(NotificationPreference pref) onSave;

  const _DndSheet({required this.initial, required this.onSave});

  @override
  State<_DndSheet> createState() => _DndSheetState();
}

class _DndSheetState extends State<_DndSheet> {
  late bool _enabled;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.dndEnabled;
    _start = _parseTime(widget.initial.dndStart);
    _end = _parseTime(widget.initial.dndEnd);
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        if (isStart) _start = picked; else _end = picked;
      });
    }
  }

  void _save() {
    widget.onSave(NotificationPreference(
      dndEnabled: _enabled,
      dndStart: _formatTime(_start),
      dndEnd: _formatTime(_end),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Do Not Disturb',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Urgent messages always bypass DND.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable Do Not Disturb'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          if (_enabled) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Quiet hours start',
                    time: _start,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: 'Quiet hours end',
                    time: _end,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Overnight ranges work (e.g. 22:00 → 07:00)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted = time.format(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.indigo.shade400),
                const SizedBox(width: 4),
                Text(
                  formatted,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
