class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type;
  final String? entityType;
  final int? entityId;
  final bool isRead;
  final String? readAt;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.entityType,
    this.entityId,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        title: j['title'] ?? '',
        message: j['message'] ?? '',
        type: j['type'] ?? 'info',
        entityType: j['entityType'],
        entityId: j['entityId'],
        isRead: j['isRead'] ?? false,
        readAt: j['readAt'],
        createdAt: j['createdAt'] ?? '',
      );
}
