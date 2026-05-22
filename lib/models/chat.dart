class ChatReaction {
  final String emoji;
  final List<int> userIds;

  ChatReaction({required this.emoji, required this.userIds});

  factory ChatReaction.fromJson(Map<String, dynamic> j) => ChatReaction(
        emoji: j['emoji'],
        userIds: List<int>.from(j['userIds'] ?? []),
      );
}

class ChatSender {
  final int id;
  final String username;
  final String? employeeName;
  final String? photo;

  ChatSender({required this.id, required this.username, this.employeeName, this.photo});

  factory ChatSender.fromJson(Map<String, dynamic> j) => ChatSender(
        id: j['id'],
        username: j['username'],
        employeeName: j['employee']?['firstName'] != null
            ? '${j['employee']['firstName']} ${j['employee']['lastName'] ?? ''}'.trim()
            : j['employeeName'],
        photo: j['photo'] ?? j['employee']?['photo'],
      );

  String get displayName => employeeName ?? username;
}

class ChatMessage {
  final int id;
  final String content;
  final String type;
  final int channelId;
  final int? parentId;
  final bool isPinned;
  final bool isEdited;
  final bool isDeleted;
  final String urgencyLevel; // 'normal' | 'urgent'
  final ChatSender? sender;
  final List<ChatReaction> reactions;
  final String createdAt;
  // File fields
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;

  bool get isUrgent => urgencyLevel == 'urgent';

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.channelId,
    this.parentId,
    required this.isPinned,
    required this.isEdited,
    required this.isDeleted,
    required this.urgencyLevel,
    this.sender,
    required this.reactions,
    required this.createdAt,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        content: j['content'] ?? '',
        type: j['type'] ?? 'text',
        channelId: j['channelId'],
        parentId: j['parentId'] ?? j['parentMessageId'],
        isPinned: j['isPinned'] ?? false,
        isEdited: j['isEdited'] ?? false,
        isDeleted: j['isDeleted'] ?? false,
        urgencyLevel: j['urgencyLevel'] ?? 'normal',
        sender: j['sender'] != null ? ChatSender.fromJson(j['sender']) : null,
        reactions: (j['reactions'] as List? ?? [])
            .map((r) => ChatReaction.fromJson(r))
            .toList(),
        createdAt: j['createdAt'] ?? '',
        fileUrl: j['fileUrl'],
        fileName: j['fileName'],
        fileSize: j['fileSize'],
        fileType: j['fileType'],
      );

  ChatMessage copyWith({String? content, bool? isDeleted, bool? isEdited}) => ChatMessage(
        id: id,
        content: content ?? this.content,
        type: type,
        channelId: channelId,
        parentId: parentId,
        isPinned: isPinned,
        isEdited: isEdited ?? this.isEdited,
        isDeleted: isDeleted ?? this.isDeleted,
        urgencyLevel: urgencyLevel,
        sender: sender,
        reactions: reactions,
        createdAt: createdAt,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
      );
}

class ChatChannel {
  final int id;
  final String name;
  final String type;
  final String? description;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final List<ChatMember> members;
  final String notificationLevel; // 'all' | 'mentions' | 'muted' | 'priority'

  ChatChannel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.lastMessage,
    required this.unreadCount,
    required this.members,
    required this.notificationLevel,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
        id: j['id'],
        name: j['name'] ?? '',
        type: j['type'] ?? 'group',
        description: j['description'],
        lastMessage: j['lastMessage'] != null ? ChatMessage.fromJson(j['lastMessage']) : null,
        unreadCount: j['unread'] ?? j['unreadCount'] ?? 0,
        members: ((j['members'] ?? j['participants'] ?? j['users'] ?? []) as List)
            .map((m) => ChatMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        notificationLevel: j['notificationLevel'] ?? 'all',
      );

  String displayName(int myUserId) {
    if (type == 'dm') {
      if (members.isEmpty) return 'Direct Message';
      try {
        return members.firstWhere((m) => m.id != myUserId).displayName;
      } catch (_) {
        return members.first.displayName;
      }
    }
    return name;
  }

  ChatMember? otherMember(int myUserId) {
    if (type != 'dm') return null;
    try {
      return members.firstWhere((m) => m.id != myUserId);
    } catch (_) {
      return null;
    }
  }
}

class ChatMember {
  final int id;
  final String username;
  final String? employeeName;
  final bool isOnline;

  ChatMember({required this.id, required this.username, this.employeeName, required this.isOnline});

  factory ChatMember.fromJson(Map<String, dynamic> j) {
    String? empName = j['employeeName'];
    if (empName == null && j['employee'] != null) {
      final fn = j['employee']['firstName'];
      final ln = j['employee']['lastName'];
      if (fn != null) empName = '$fn${ln != null ? ' $ln' : ''}';
    }
    return ChatMember(
      id: j['id'] ?? j['userId'],
      username: j['username'] ?? '',
      employeeName: empName,
      isOnline: j['isOnline'] ?? false,
    );
  }

  String get displayName => employeeName ?? username;

  String get initials {
    final name = displayName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── New models ────────────────────────────────────────────────────────────────

class ChatTask {
  final int id;
  final String title;
  final String? description;
  final String priority; // low | medium | high | urgent
  final String status;   // todo | in_progress | waiting_client | testing | completed
  final String? dueDate;
  final int? sourceMessageId;
  final ChatSender? assignedTo;
  final ChatSender? createdBy;
  final String createdAt;

  ChatTask({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.dueDate,
    this.sourceMessageId,
    this.assignedTo,
    this.createdBy,
    required this.createdAt,
  });

  factory ChatTask.fromJson(Map<String, dynamic> j) => ChatTask(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'],
        priority: j['priority'] ?? 'medium',
        status: j['status'] ?? 'todo',
        dueDate: j['dueDate'],
        sourceMessageId: j['sourceMessageId'],
        assignedTo: j['assignedTo'] != null ? ChatSender.fromJson(j['assignedTo']) : null,
        createdBy: j['createdBy'] != null ? ChatSender.fromJson(j['createdBy']) : null,
        createdAt: j['createdAt'] ?? '',
      );

  static const statusLabels = {
    'todo': 'To Do',
    'in_progress': 'In Progress',
    'waiting_client': 'Waiting for Client',
    'testing': 'Testing',
    'completed': 'Completed',
  };

  static const priorityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'urgent': 'Urgent',
  };

  String get statusLabel => statusLabels[status] ?? status;
  String get priorityLabel => priorityLabels[priority] ?? priority;

  bool get isOverdue {
    if (dueDate == null || status == 'completed') return false;
    return DateTime.tryParse(dueDate!)?.isBefore(DateTime.now()) ?? false;
  }
}

class NotificationPreference {
  final bool dndEnabled;
  final String dndStart; // HH:MM
  final String dndEnd;   // HH:MM

  NotificationPreference({
    required this.dndEnabled,
    required this.dndStart,
    required this.dndEnd,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> j) =>
      NotificationPreference(
        dndEnabled: j['dndEnabled'] ?? false,
        dndStart: j['dndStart'] ?? '22:00',
        dndEnd: j['dndEnd'] ?? '07:00',
      );

  factory NotificationPreference.defaults() =>
      NotificationPreference(dndEnabled: false, dndStart: '22:00', dndEnd: '07:00');

  bool get isActiveNow {
    if (!dndEnabled) return false;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final start = _parse(dndStart);
    final end = _parse(dndEnd);
    if (start <= end) return current >= start && current <= end;
    return current >= start || current <= end; // overnight
  }

  static int _parse(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
