import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/socket/socket_service.dart';
import '../../core/auth/token_storage.dart';
import '../../models/chat.dart';
import '../../widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  final ChatChannel channel;
  const ChatScreen({super.key, required this.channel});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient().dio;
  final _socket = SocketService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _hasMore = true;
  bool _sending = false;
  String? _typingUser;
  Timer? _typingTimer;
  late int _myUserId;

  bool _showEmoji = false;
  String? _mentionQuery;  // non-null when @query is active
  String? _tagQuery;      // non-null when #query is active

  static const _commonTags = [
    'urgent', 'followup', 'meeting', 'support',
    'development', 'sales', 'invoice', 'task', 'update', 'resolved',
  ];

  @override
  void initState() {
    super.initState();
    _myUserId = context.read<AuthProvider>().user!.id;
    _loadMessages();
    _setupSocket();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <= 100) _loadOlder();
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
  }

  @override
  void dispose() {
    _socket.leaveChannel(widget.channel.id);
    _socket.off('new_message');
    _socket.off('message_edited');
    _socket.off('message_deleted');
    _socket.off('user_typing');
    _socket.off('user_stop_typing');
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _setupSocket() async {
    final token = await TokenStorage.getToken();
    if (token != null) _socket.connect(token);
    _socket.joinChannel(widget.channel.id);
    _socket.markRead(widget.channel.id);

    _socket.on('new_message', (data) {
      final msg = ChatMessage.fromJson(data is Map ? Map<String, dynamic>.from(data) : {});
      if (msg.channelId == widget.channel.id && mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
        _socket.markRead(widget.channel.id);
      }
    });

    _socket.on('message_edited', (data) {
      final msg = ChatMessage.fromJson(data is Map ? Map<String, dynamic>.from(data) : {});
      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) setState(() => _messages[idx] = msg);
      }
    });

    _socket.on('message_deleted', (data) {
      final msgId = data['messageId'];
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == msgId));
    });

    _socket.on('user_typing', (data) {
      if (data['channelId'] == widget.channel.id && mounted) {
        setState(() => _typingUser = data['username']);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typingUser = null);
        });
      }
    });

    _socket.on('user_stop_typing', (data) {
      if (data['channelId'] == widget.channel.id && mounted) {
        setState(() => _typingUser = null);
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get(
        '${ApiConstants.chatChannels}/${widget.channel.id}/messages',
        queryParameters: {'limit': 50},
      );
      final loaded = (res.data as List).map((j) => ChatMessage.fromJson(j)).toList();
      setState(() {
        _messages = loaded;
        _hasMore = loaded.length == 50;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _messages.isEmpty) return;
    try {
      final res = await _api.get(
        '${ApiConstants.chatChannels}/${widget.channel.id}/messages',
        queryParameters: {'before': _messages.first.id, 'limit': 50},
      );
      final loaded = (res.data as List).map((j) => ChatMessage.fromJson(j)).toList();
      if (loaded.isNotEmpty) {
        final savedOffset = _scrollCtrl.position.pixels;
        setState(() {
          _messages.insertAll(0, loaded);
          _hasMore = loaded.length == 50;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + (savedOffset > 0 ? 200 : 0));
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _onChanged(String text) {
    // Emit typing indicator
    _socket.emitTyping(widget.channel.id);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _socket.emitStopTyping(widget.channel.id);
    });

    // Detect @mention or #tag at cursor position
    final cursor = _msgCtrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      setState(() { _mentionQuery = null; _tagQuery = null; });
      return;
    }
    final before = text.substring(0, cursor);

    final mentionMatch = RegExp(r'@(\w*)$').firstMatch(before);
    if (mentionMatch != null) {
      setState(() { _mentionQuery = mentionMatch.group(1)!.toLowerCase(); _tagQuery = null; });
      return;
    }

    final tagMatch = RegExp(r'#(\w*)$').firstMatch(before);
    if (tagMatch != null) {
      setState(() { _tagQuery = tagMatch.group(1)!.toLowerCase(); _mentionQuery = null; });
      return;
    }

    setState(() { _mentionQuery = null; _tagQuery = null; });
  }

  void _insertMention(ChatMember member) {
    _replaceCurrentToken('@', '${member.username} ');
    setState(() => _mentionQuery = null);
  }

  void _insertTag(String tag) {
    _replaceCurrentToken('#', '$tag ');
    setState(() => _tagQuery = null);
  }

  void _replaceCurrentToken(String prefix, String replacement) {
    final text = _msgCtrl.text;
    final cursor = _msgCtrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final match = RegExp('\\${prefix}(\\w*)\$').firstMatch(before);
    if (match == null) return;
    final newBefore = before.substring(0, match.start) + prefix + replacement;
    _msgCtrl.value = TextEditingValue(
      text: newBefore + after,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    setState(() { _mentionQuery = null; _tagQuery = null; });
    _socket.sendMessage(channelId: widget.channel.id, content: text);
    setState(() => _sending = false);
  }

  List<ChatMember> get _filteredMembers {
    final q = _mentionQuery ?? '';
    return widget.channel.members
        .where((m) => m.id != _myUserId)
        .where((m) =>
            q.isEmpty ||
            m.username.toLowerCase().contains(q) ||
            m.displayName.toLowerCase().contains(q))
        .toList();
  }

  List<String> get _filteredTags {
    final q = _tagQuery ?? '';
    return _commonTags.where((t) => q.isEmpty || t.startsWith(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDm = widget.channel.type == 'dm';
    final other = isDm ? widget.channel.otherMember(_myUserId) : null;
    final displayName = widget.channel.displayName(_myUserId);

    return Scaffold(
      resizeToAvoidBottomInset: !_showEmoji,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (isDm && other != null)
              Text(
                other.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: other.isOnline ? Colors.greenAccent[100] : Colors.white60,
                ),
              ),
          ],
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: _messages[i],
                      isMe: _messages[i].sender?.id == _myUserId,
                      onLongPress: () => _messageActions(context, _messages[i]),
                    ),
                  ),
          ),

          // @mention suggestions
          if (_mentionQuery != null && _filteredMembers.isNotEmpty)
            _SuggestionBar(
              children: _filteredMembers.map((m) => _SuggestionChip(
                avatar: m.initials,
                label: m.displayName,
                sublabel: '@${m.username}',
                color: Colors.blue,
                onTap: () => _insertMention(m),
              )).toList(),
            ),

          // #tag suggestions
          if (_tagQuery != null && _filteredTags.isNotEmpty)
            _SuggestionBar(
              children: _filteredTags.map((t) => _SuggestionChip(
                avatar: '#',
                label: t,
                sublabel: '#$t',
                color: Colors.green,
                onTap: () => _insertTag(t),
              )).toList(),
            ),

          // Typing indicator
          if (_typingUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_typingUser is typing...',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            ),

          const Divider(height: 1),

          // Input row
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                      color: _showEmoji
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600],
                    ),
                    onPressed: _toggleEmoji,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Message... @ mention  # tag',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        filled: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Emoji picker panel
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  final cursor =
                      _msgCtrl.selection.baseOffset.clamp(0, _msgCtrl.text.length);
                  final text = _msgCtrl.text;
                  final newText =
                      text.substring(0, cursor) + emoji.emoji + text.substring(cursor);
                  _msgCtrl.value = TextEditingValue(
                    text: newText,
                    selection:
                        TextSelection.collapsed(offset: cursor + emoji.emoji.length),
                  );
                },
                config: Config(
                  height: 280,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    columns: 9,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _messageActions(BuildContext context, ChatMessage msg) {
    final user = context.read<AuthProvider>().user!;
    final isOwn = msg.sender?.id == _myUserId;
    if (!isOwn && !user.isAdmin) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwn)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(context, msg);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await _api.delete(
                    '${ApiConstants.chatChannels.replaceAll('/channels', '')}/messages/${msg.id}');
                setState(() => _messages.removeWhere((m) => m.id == msg.id));
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  void _editMessage(BuildContext context, ChatMessage msg) {
    final ctrl = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(controller: ctrl, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final res =
                    await _api.put('/chat/messages/${msg.id}', data: {'content': ctrl.text});
                final updated = ChatMessage.fromJson(res.data);
                final idx = _messages.indexWhere((m) => m.id == msg.id);
                if (idx != -1) setState(() => _messages[idx] = updated);
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion UI ─────────────────────────────────────────────────────────────

class _SuggestionBar extends StatelessWidget {
  final List<Widget> children;
  const _SuggestionBar({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, -1))],
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: children,
        ),
      );
}

class _SuggestionChip extends StatelessWidget {
  final String avatar;
  final String label;
  final String sublabel;
  final MaterialColor color;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.avatar,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: color[100],
                child: Text(avatar,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: color[700])),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color[900])),
            ],
          ),
        ),
      );
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback onLongPress;

  const _MessageBubble(
      {required this.message, required this.isMe, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(message.createdAt);
    final timeStr = time != null ? DateFormat('HH:mm').format(time) : '';
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? primary : Colors.grey[200],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && message.sender != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.sender!.displayName,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700]),
                  ),
                ),
              _buildRichText(message.content, isMe, primary),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited)
                    Text('edited • ',
                        style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white54 : Colors.grey)),
                  Text(timeStr,
                      style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white54 : Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichText(String content, bool isMe, Color primary) {
    final regex = RegExp(r'(@\w+|#\w+)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    final baseStyle =
        TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14);
    final mentionStyle = TextStyle(
      color: isMe ? Colors.lightBlue[100] : Colors.blue[700],
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    final tagStyle = TextStyle(
      color: isMe ? Colors.greenAccent[100] : Colors.green[700],
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
            text: content.substring(lastEnd, match.start), style: baseStyle));
      }
      final token = match.group(0)!;
      spans.add(
          TextSpan(text: token, style: token.startsWith('@') ? mentionStyle : tagStyle));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
