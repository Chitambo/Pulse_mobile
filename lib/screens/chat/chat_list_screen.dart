import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/chat.dart';
import '../../widgets/common_widgets.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _api = ApiClient().dio;
  List<ChatChannel> _channels = [];
  bool _loading = true;
  String? _error;
  late int _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = context.read<AuthProvider>().user!.id;
    _load();
  }

  Future<void> _load() async {
    final cached = await CacheStore().getList('channels', page: 1);
    if (cached != null && mounted) {
      setState(() {
        _channels = cached.map((j) => ChatChannel.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } else {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final res = await _api.get(ApiConstants.chatChannels);
      final items = res.data as List;
      await CacheStore().saveList('channels', 1, items);
      setState(() {
        _channels = items.map((j) => ChatChannel.fromJson(j)).toList();
      });
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Error');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openChannel(ChatChannel channel) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(channel: channel)))
        .then((_) => _load());
  }

  void _startDm(BuildContext context) async {
    final res = await _api.get(ApiConstants.chatUsers);
    final users = (res.data as List).cast<Map<String, dynamic>>();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start Direct Message'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              return ListTile(
                title: Text(u['username'] ?? ''),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final dmRes = await _api.post(ApiConstants.chatDm, data: {'userId': u['id']});
                    final channel = ChatChannel.fromJson(dmRes.data);
                    if (mounted) _openChannel(channel);
                  } catch (_) {}
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(icon: const Icon(Icons.group_add), onPressed: () => _createGroup(context)),
          IconButton(icon: const Icon(Icons.person_add), onPressed: () => _startDm(context)),
        ],
      ),
      body: _loading
          ? const ShimmerList()
          : _error != null
              ? ErrorRetryWidget(message: _error!, onRetry: _load)
              : _channels.isEmpty
                  ? const EmptyWidget(message: 'No conversations yet', icon: Icons.chat_bubble_outline)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _channels.length,
                        itemBuilder: (_, i) => _ChannelTile(
                          channel: _channels[i],
                          myUserId: _myUserId,
                          onTap: () => _openChannel(_channels[i]),
                        ),
                      ),
                    ),
    );
  }

  void _createGroup(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Group'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(context);
              try {
                await _api.post(ApiConstants.chatChannels, data: {'name': nameCtrl.text.trim()});
                _load();
              } catch (_) {}
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final ChatChannel channel;
  final int myUserId;
  final VoidCallback onTap;
  const _ChannelTile({required this.channel, required this.myUserId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final last = channel.lastMessage;
    final isDm = channel.type == 'dm';
    final other = isDm ? channel.otherMember(myUserId) : null;
    final displayName = channel.displayName(myUserId);
    final isOnline = other?.isOnline ?? false;

    final initials = other?.initials ??
        (displayName.isNotEmpty ? displayName[0].toUpperCase() : '#');

    final avatarBg = isDm ? Colors.blue[100]! : Colors.green[100]!;
    final avatarFg = isDm ? Colors.blue[700]! : Colors.green[700]!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: avatarBg,
            child: isDm
                ? Text(initials, style: TextStyle(color: avatarFg, fontWeight: FontWeight.bold))
                : Icon(Icons.group, color: avatarFg),
          ),
          if (isDm && isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          if (channel.unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: Text('${channel.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: channel.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: last != null
          ? Text(
              last.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: channel.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                color: channel.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
              ),
            )
          : Text('No messages yet',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[500])),
      trailing: last != null
          ? Text(timeago.format(DateTime.tryParse(last.createdAt) ?? DateTime.now()),
              style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
      onTap: onTap,
    );
  }
}
