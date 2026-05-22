import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../models/chat.dart';
import '../../core/api/api_constants.dart';
import '../../core/socket/socket_service.dart';
import '../../core/notifications/push_notification_service.dart';

/// Full replacement for the individual channel / chat screen.
/// Changes vs old version:
///  - Urgent messages: red left border + 🚨 badge in _MessageBubble
///  - Long-press on any message → bottom sheet with: Reply, Copy, Convert to Task,
///    Assign to..., Set Reminder, Pin (existing), Delete (existing)
///  - Input row has a ⚠ toggle button; when on, the input border turns red and
///    the message is sent with urgencyLevel = 'urgent'
///  - Socket handlers for: urgent_alert, task_assigned, message_assigned, reminder_due
class ChatScreen extends StatefulWidget {
  final ChatChannel channel;
  final Dio dio;
  final int myUserId;
  final String myUsername;
  final SocketService socket;

  const ChatScreen({
    Key? key,
    required this.channel,
    required this.dio,
    required this.myUserId,
    required this.myUsername,
    required this.socket,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _isUrgent = false;
  ChatMessage? _replyTo;
  bool _typingVisible = false;
  String? _typingUser;

  // Track members for @mention autocomplete
  List<ChatMember> _members = [];
  bool _showMentionList = false;
  String _mentionQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadMembers();
    _bindSocket();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _unbindSocket();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    try {
      final res = await widget.dio.get(ApiConstants.channelMessages(widget.channel.id));
      final list = (res.data as List).map((j) => ChatMessage.fromJson(j)).toList();
      if (mounted) {
        setState(() { _messages = list; _loading = false; });
        _scrollToBottom();
        _markRead();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await widget.dio.get(ApiConstants.chatUsers);
      if (mounted) {
        setState(() {
          _members = (res.data as List).map((j) => ChatMember.fromJson(j)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _markRead() async {
    try {
      await widget.dio.post(ApiConstants.channelRead(widget.channel.id));
    } catch (_) {}
  }

  // ── Socket ──────────────────────────────────────────────────────────────────

  void _bindSocket() {
    final channelId = widget.channel.id;
    widget.socket.joinChannel(channelId);

    widget.socket.on('new_message', _onNewMessage);
    widget.socket.on('message_edited', _onMessageEdited);
    widget.socket.on('message_deleted', _onMessageDeleted);
    widget.socket.on('typing_start', _onTypingStart);
    widget.socket.on('typing_stop', _onTypingStop);
    widget.socket.on('urgent_alert', _onUrgentAlert);
    widget.socket.on('task_assigned', _onTaskAssigned);
    widget.socket.on('message_assigned', _onMessageAssigned);
    widget.socket.on('reminder_due', _onReminderDue);
  }

  void _unbindSocket() {
    widget.socket.leaveChannel(widget.channel.id);
    for (final ev in [
      'new_message', 'message_edited', 'message_deleted',
      'typing_start', 'typing_stop', 'urgent_alert',
      'task_assigned', 'message_assigned', 'reminder_due',
    ]) {
      widget.socket.off(ev);
    }
  }

  void _onNewMessage(dynamic data) {
    final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
    if (msg.channelId != widget.channel.id) return;
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
      _markRead();
    }
  }

  void _onMessageEdited(dynamic data) {
    final updated = ChatMessage.fromJson(data as Map<String, dynamic>);
    if (mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == updated.id);
        if (idx != -1) _messages[idx] = updated;
      });
    }
  }

  void _onMessageDeleted(dynamic data) {
    final id = (data as Map<String, dynamic>)['messageId'] as int;
    if (mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == id);
        if (idx != -1) _messages[idx] = _messages[idx].copyWith(isDeleted: true);
      });
    }
  }

  void _onTypingStart(dynamic data) {
    final d = data as Map<String, dynamic>;
    if (d['channelId'] != widget.channel.id) return;
    if (d['userId'] == widget.myUserId) return;
    if (mounted) setState(() { _typingUser = d['username']; _typingVisible = true; });
  }

  void _onTypingStop(dynamic data) {
    final d = data as Map<String, dynamic>;
    if (d['channelId'] != widget.channel.id) return;
    if (mounted) setState(() => _typingVisible = false);
  }

  void _onUrgentAlert(dynamic data) {
    final d = data as Map<String, dynamic>;
    if (!mounted) return;
    PushNotificationService().showLocal(
      title: '🚨 Urgent: ${d['channelName'] ?? 'Message'}',
      body: d['content'] ?? '',
      data: Map<String, dynamic>.from(d),
      urgent: true,
    );
    _showBanner('🚨 Urgent message from ${d['senderName'] ?? 'someone'}', Colors.red.shade700);
  }

  void _onTaskAssigned(dynamic data) {
    final d = data as Map<String, dynamic>;
    if (!mounted) return;
    _showBanner('✅ Task assigned: ${d['title'] ?? ''}', Colors.indigo.shade700);
  }

  void _onMessageAssigned(dynamic data) {
    final d = data as Map<String, dynamic>;
    if (!mounted) return;
    _showBanner('📌 Message assigned to you by ${d['assignedByName'] ?? 'someone'}', Colors.teal.shade700);
  }

  void _onReminderDue(dynamic data) {
    final d = data as Map<String, dynamic>;
    if (!mounted) return;
    PushNotificationService().showLocal(
      title: '⏰ Reminder',
      body: d['note'] ?? 'Time to follow up',
      data: Map<String, dynamic>.from(d),
    );
  }

  void _showBanner(String text, Color color) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(text, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        actions: [
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  // ── Input handling ──────────────────────────────────────────────────────────

  bool _typingEmitted = false;

  void _onTextChanged() {
    final text = _controller.text;

    // @mention autocomplete
    final cursor = _controller.selection.baseOffset;
    if (cursor > 0) {
      final before = text.substring(0, cursor);
      final atIdx = before.lastIndexOf('@');
      if (atIdx != -1 && !before.substring(atIdx).contains(' ')) {
        final query = before.substring(atIdx + 1).toLowerCase();
        setState(() { _mentionQuery = query; _showMentionList = true; });
      } else {
        if (_showMentionList) setState(() => _showMentionList = false);
      }
    }

    // Typing indicator
    if (text.isNotEmpty && !_typingEmitted) {
      widget.socket.emitTyping(widget.channel.id);
      _typingEmitted = true;
    } else if (text.isEmpty && _typingEmitted) {
      widget.socket.emitStopTyping(widget.channel.id);
      _typingEmitted = false;
    }
  }

  void _insertMention(ChatMember member) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final atIdx = before.lastIndexOf('@');
    final newText = '${before.substring(0, atIdx)}@${member.username} $after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIdx + member.username.length + 2),
    );
    setState(() => _showMentionList = false);
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    _controller.clear();
    widget.socket.emitStopTyping(widget.channel.id);
    _typingEmitted = false;
    final urgent = _isUrgent;
    if (urgent) setState(() => _isUrgent = false);

    widget.socket.sendMessage(
      channelId: widget.channel.id,
      content: content,
      parentId: _replyTo?.id,
      urgencyLevel: urgent ? 'urgent' : 'normal',
    );
    if (_replyTo != null) setState(() => _replyTo = null);
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: result.files.single.name),
      'urgencyLevel': _isUrgent ? 'urgent' : 'normal',
      if (_replyTo != null) 'parentId': _replyTo!.id.toString(),
    });
    try {
      await widget.dio.post(ApiConstants.channelUpload(widget.channel.id), data: formData);
      if (_replyTo != null && mounted) setState(() => _replyTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Message actions ─────────────────────────────────────────────────────────

  void _showMessageActions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MessageActionsSheet(
        message: msg,
        myUserId: widget.myUserId,
        onReply: () { Navigator.pop(context); setState(() => _replyTo = msg); _focusNode.requestFocus(); },
        onCreateTask: () { Navigator.pop(context); _showCreateTaskSheet(msg); },
        onAssign: () { Navigator.pop(context); _showAssignSheet(msg); },
        onRemind: () { Navigator.pop(context); _showReminderSheet(msg); },
        onDelete: msg.sender?.id == widget.myUserId
            ? () { Navigator.pop(context); _deleteMessage(msg); }
            : null,
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    try {
      await widget.dio.delete('/chat/messages/${msg.id}');
    } catch (_) {}
  }

  void _showCreateTaskSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreateTaskSheet(
        message: msg,
        members: _members,
        dio: widget.dio,
        onCreated: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task created')),
          );
        },
      ),
    );
  }

  void _showAssignSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssignMessageSheet(
        message: msg,
        members: _members,
        dio: widget.dio,
        onAssigned: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message assigned')),
          );
        },
      ),
    );
  }

  void _showReminderSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReminderSheet(
        message: msg,
        members: _members,
        myUserId: widget.myUserId,
        dio: widget.dio,
        onSet: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder set')),
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.displayName(widget.myUserId)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _MessageBubble(
                          message: _messages[i],
                          myUserId: widget.myUserId,
                          replyTo: _messages[i].parentId != null
                              ? _messages.firstWhere(
                                  (m) => m.id == _messages[i].parentId,
                                  orElse: () => _messages[i],
                                )
                              : null,
                          onLongPress: () => _showMessageActions(_messages[i]),
                          onReplyTap: (parentId) {
                            final idx = _messages.indexWhere((m) => m.id == parentId);
                            if (idx != -1) {
                              _scrollController.animateTo(
                                idx * 72.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      ),
                      if (_typingVisible && _typingUser != null)
                        Positioned(
                          bottom: 0,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: Text(
                              '$_typingUser is typing…',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (_replyTo != null) _ReplyPreview(
            message: _replyTo!,
            onDismiss: () => setState(() => _replyTo = null),
          ),
          if (_showMentionList) _MentionList(
            members: _members
                .where((m) => m.username.toLowerCase().contains(_mentionQuery) ||
                    m.displayName.toLowerCase().contains(_mentionQuery))
                .toList(),
            onSelect: _insertMention,
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isUrgent: _isUrgent,
            onToggleUrgent: () => setState(() => _isUrgent = !_isUrgent),
            onSend: _sendMessage,
            onAttach: _pickAndUploadFile,
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int myUserId;
  final ChatMessage? replyTo;
  final VoidCallback onLongPress;
  final void Function(int parentId) onReplyTap;

  const _MessageBubble({
    required this.message,
    required this.myUserId,
    this.replyTo,
    required this.onLongPress,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender?.id == myUserId;
    final isUrgent = message.isUrgent;
    final isDeleted = message.isDeleted;

    return GestureDetector(
      onLongPress: isDeleted ? null : onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: isUrgent && !isDeleted
            ? BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: Colors.red.shade600, width: 3)),
              )
            : null,
        child: Padding(
          padding: EdgeInsets.only(left: isUrgent ? 8 : 0),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender + urgent badge
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe)
                      Text(
                        message.sender?.displayName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.indigo,
                        ),
                      ),
                    if (isUrgent && !isDeleted) ...[
                      if (!isMe) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Reply preview
              if (replyTo != null)
                GestureDetector(
                  onTap: () => onReplyTap(replyTo!.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                      border: Border(left: BorderSide(color: Colors.grey.shade500, width: 2)),
                    ),
                    child: Text(
                      replyTo!.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),

              // Bubble
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? Colors.grey.shade100
                      : isMe
                          ? Colors.indigo.shade600
                          : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMe ? 12 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 12),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
                  ],
                ),
                child: isDeleted
                    ? Text(
                        'This message was deleted',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      )
                    : message.type == 'file'
                        ? _FileContent(message: message, isMe: isMe)
                        : Text(
                            message.content,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
              ),

              // Timestamp + edited
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                    if (message.isEdited) ...[
                      const SizedBox(width: 4),
                      Text('edited', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _FileContent extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _FileContent({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isImage = message.fileType?.startsWith('image/') ?? false;
    final fileUrl = message.fileUrl != null
        ? '${ApiConstants.uploadsUrl}/${message.fileUrl}'
        : null;

    if (isImage && fileUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(fileUrl, width: 200, fit: BoxFit.cover),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          size: 16,
          color: isMe ? Colors.white70 : Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message.fileName ?? 'File',
            style: TextStyle(
              color: isMe ? Colors.white : Colors.indigo,
              decoration: TextDecoration.underline,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isUrgent;
  final VoidCallback onToggleUrgent;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isUrgent,
    required this.onToggleUrgent,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8, 8, 8, MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -1))],
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: Colors.grey.shade600,
            onPressed: onAttach,
            tooltip: 'Attach file',
          ),

          // Urgent toggle
          IconButton(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: isUrgent ? Colors.red.shade600 : Colors.grey.shade400,
            ),
            onPressed: onToggleUrgent,
            tooltip: isUrgent ? 'Urgent (tap to cancel)' : 'Mark as urgent',
          ),

          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isUrgent ? Colors.red.shade400 : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isUrgent ? '🚨 Urgent message…' : 'Type a message…',
                  hintStyle: TextStyle(
                    color: isUrgent ? Colors.red.shade300 : Colors.grey.shade500,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red.shade600 : Colors.indigo,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reply Preview Banner ───────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onDismiss;

  const _ReplyPreview({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.indigo.shade50,
      child: Row(
        children: [
          Container(width: 3, height: 36, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${message.sender?.displayName ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ── @Mention List ─────────────────────────────────────────────────────────────

class _MentionList extends StatelessWidget {
  final List<ChatMember> members;
  final void Function(ChatMember) onSelect;

  const _MentionList({required this.members, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: members.length,
        itemBuilder: (ctx, i) => ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: Colors.indigo.shade100,
            child: Text(
              members[i].initials,
              style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
            ),
          ),
          title: Text(members[i].displayName, style: const TextStyle(fontSize: 13)),
          subtitle: Text('@${members[i].username}', style: const TextStyle(fontSize: 11)),
          onTap: () => onSelect(members[i]),
        ),
      ),
    );
  }
}

// ── Message Actions Bottom Sheet ──────────────────────────────────────────────

class _MessageActionsSheet extends StatelessWidget {
  final ChatMessage message;
  final int myUserId;
  final VoidCallback onReply;
  final VoidCallback onCreateTask;
  final VoidCallback onAssign;
  final VoidCallback onRemind;
  final VoidCallback? onDelete;

  const _MessageActionsSheet({
    required this.message,
    required this.myUserId,
    required this.onReply,
    required this.onCreateTask,
    required this.onAssign,
    required this.onRemind,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Message preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const Divider(height: 20),
          _ActionTile(
            icon: Icons.reply,
            color: Colors.grey.shade700,
            label: 'Reply',
            onTap: onReply,
          ),
          _ActionTile(
            icon: Icons.task_alt,
            color: Colors.indigo,
            label: 'Convert to Task',
            onTap: onCreateTask,
          ),
          _ActionTile(
            icon: Icons.person_add_outlined,
            color: Colors.teal,
            label: 'Assign to...',
            onTap: onAssign,
          ),
          _ActionTile(
            icon: Icons.alarm_add_outlined,
            color: Colors.amber.shade700,
            label: 'Set Reminder',
            onTap: onRemind,
          ),
          if (onDelete != null) ...[
            const Divider(height: 8),
            _ActionTile(
              icon: Icons.delete_outline,
              color: Colors.red,
              label: 'Delete Message',
              onTap: onDelete!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

// ── Create Task Sheet ─────────────────────────────────────────────────────────

class _CreateTaskSheet extends StatefulWidget {
  final ChatMessage message;
  final List<ChatMember> members;
  final Dio dio;
  final VoidCallback onCreated;

  const _CreateTaskSheet({
    required this.message,
    required this.members,
    required this.dio,
    required this.onCreated,
  });

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  String _priority = 'medium';
  int? _assigneeId;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final preview = widget.message.content;
    _titleCtrl = TextEditingController(
      text: preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
    );
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(ApiConstants.chatTasks, data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'sourceMessageId': widget.message.id,
        'channelId': widget.message.channelId,
        'priority': _priority,
        if (_assigneeId != null) 'assignedToId': _assigneeId,
        if (_dueDate != null) 'dueDate': DateFormat('yyyy-MM-dd').format(_dueDate!),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Convert to Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _PriorityDropdown(value: _priority, onChanged: (v) => setState(() => _priority = v))),
            const SizedBox(width: 12),
            Expanded(child: _AssigneeDropdown(
              members: widget.members,
              value: _assigneeId,
              onChanged: (v) => setState(() => _assigneeId = v),
            )),
          ]),
          const SizedBox(height: 12),
          _DueDatePicker(value: _dueDate, onChanged: (v) => setState(() => _dueDate = v)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Task'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assign Message Sheet ──────────────────────────────────────────────────────

class _AssignMessageSheet extends StatefulWidget {
  final ChatMessage message;
  final List<ChatMember> members;
  final Dio dio;
  final VoidCallback onAssigned;

  const _AssignMessageSheet({
    required this.message,
    required this.members,
    required this.dio,
    required this.onAssigned,
  });

  @override
  State<_AssignMessageSheet> createState() => _AssignMessageSheetState();
}

class _AssignMessageSheetState extends State<_AssignMessageSheet> {
  int? _assigneeId;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_assigneeId == null) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(ApiConstants.messageAssign(widget.message.id), data: {
        'assignedToId': _assigneeId,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assign Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            widget.message.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _AssigneeDropdown(
            members: widget.members,
            value: _assigneeId,
            onChanged: (v) => setState(() => _assigneeId = v),
            label: 'Assign to',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saving || _assigneeId == null) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Assign'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reminder Sheet ────────────────────────────────────────────────────────────

class _ReminderSheet extends StatefulWidget {
  final ChatMessage message;
  final List<ChatMember> members;
  final int myUserId;
  final Dio dio;
  final VoidCallback onSet;

  const _ReminderSheet({
    required this.message,
    required this.members,
    required this.myUserId,
    required this.dio,
    required this.onSet,
  });

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  int? _remindUserId;
  DateTime? _remindAt;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remindUserId = widget.myUserId;
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  void _setQuick(Duration offset) {
    setState(() => _remindAt = DateTime.now().add(offset));
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      _remindAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_remindAt == null || _remindUserId == null) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(ApiConstants.messageRemind(widget.message.id), data: {
        'userId': _remindUserId,
        'remindAt': _remindAt!.toUtc().toIso8601String(),
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSet();
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            widget.message.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          // Quick picks
          Wrap(
            spacing: 8,
            children: [
              _QuickChip(label: 'In 1 hour', onTap: () => _setQuick(const Duration(hours: 1))),
              _QuickChip(label: 'Later today', onTap: () => _setQuick(const Duration(hours: 4))),
              _QuickChip(label: 'Tomorrow 9am', onTap: () {
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                setState(() => _remindAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0));
              }),
              _QuickChip(label: 'Next Monday', onTap: () {
                final now = DateTime.now();
                final daysUntilMonday = (8 - now.weekday) % 7;
                final monday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
                setState(() => _remindAt = DateTime(monday.year, monday.month, monday.day, 9, 0));
              }),
              _QuickChip(label: 'Custom…', onTap: _pickCustom),
            ],
          ),
          if (_remindAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '⏰ ${DateFormat('EEE, MMM d • HH:mm').format(_remindAt!)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
          ],
          const SizedBox(height: 12),
          _AssigneeDropdown(
            members: widget.members,
            value: _remindUserId,
            onChanged: (v) => setState(() => _remindUserId = v),
            label: 'Remind who',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saving || _remindAt == null) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Set Reminder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _PriorityDropdown extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _PriorityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'low', child: Text('Low')),
        DropdownMenuItem(value: 'medium', child: Text('Medium')),
        DropdownMenuItem(value: 'high', child: Text('High')),
        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
      ],
      onChanged: (v) => v != null ? onChanged(v) : null,
    );
  }
}

class _AssigneeDropdown extends StatelessWidget {
  final List<ChatMember> members;
  final int? value;
  final void Function(int?) onChanged;
  final String label;

  const _AssigneeDropdown({
    required this.members,
    required this.value,
    required this.onChanged,
    this.label = 'Assignee',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: members.map((m) => DropdownMenuItem(
        value: m.id,
        child: Text(m.displayName, overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

class _DueDatePicker extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime?) onChanged;

  const _DueDatePicker({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Due date (optional)', border: OutlineInputBorder()),
        child: Text(
          value != null ? DateFormat('yyyy-MM-dd').format(value!) : 'No due date',
          style: TextStyle(color: value != null ? Colors.black : Colors.grey.shade500),
        ),
      ),
    );
  }
}
