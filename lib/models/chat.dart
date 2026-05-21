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
        employeeName: j['employeeName'] ?? j['employee']?['firstName'] != null
            ? '${j['employee']?['firstName']} ${j['employee']?['lastName']}'
            : null,
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
  final ChatSender? sender;
  final List<ChatReaction> reactions;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.channelId,
    this.parentId,
    required this.isPinned,
    required this.isEdited,
    this.sender,
    required this.reactions,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        content: j['content'] ?? '',
        type: j['type'] ?? 'text',
        channelId: j['channelId'],
        parentId: j['parentId'] ?? j['parentMessageId'],
        isPinned: j['isPinned'] ?? false,
        isEdited: j['isEdited'] ?? false,
        sender: j['sender'] != null ? ChatSender.fromJson(j['sender']) : null,
        reactions: (j['reactions'] as List? ?? [])
            .map((r) => ChatReaction.fromJson(r))
            .toList(),
        createdAt: j['createdAt'] ?? '',
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

  ChatChannel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.lastMessage,
    required this.unreadCount,
    required this.members,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
        id: j['id'],
        name: j['name'] ?? '',
        type: j['type'] ?? 'group',
        description: j['description'],
        lastMessage: j['lastMessage'] != null ? ChatMessage.fromJson(j['lastMessage']) : null,
        unreadCount: j['unreadCount'] ?? 0,
        members: (j['members'] as List? ?? []).map((m) => ChatMember.fromJson(m)).toList(),
      );

  String displayName(int myUserId) {
    if (type == 'dm') {
      final other = members.firstWhere(
        (m) => m.id != myUserId,
        orElse: () => members.isNotEmpty ? members.first : ChatMember(id: 0, username: name, isOnline: false),
      );
      return other.displayName;
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
