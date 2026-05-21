import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_constants.dart';
import '../core/database/cache_store.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final _api = ApiClient().dio;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  int _chatUnread = 0;
  bool _loading = false;
  int _page = 1;
  bool _hasMore = true;

  List<AppNotification> get notifications => _notifications;
  /// Combined badge: system notifications + unread chat messages.
  int get unreadCount => _unreadCount + _chatUnread;
  int get chatUnreadCount => _chatUnread;
  bool get loading => _loading;
  bool get hasMore => _hasMore;

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _notifications = [];
      final cached = await CacheStore().getList('notifications', page: 1);
      if (cached != null) {
        _notifications = cached.map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    }
    if (!_hasMore) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.notifications, queryParameters: {
        'page': _page,
        'limit': 20,
      });
      final data = res.data;
      List items;
      if (data is Map) {
        items = data['data'] ?? [];
        final pagination = data['pagination'];
        _hasMore = pagination != null && _page < (pagination['totalPages'] ?? 1);
      } else {
        items = data as List;
        _hasMore = false;
      }
      await CacheStore().saveList('notifications', _page, items);
      final loaded = items.map((j) => AppNotification.fromJson(j)).toList();
      if (refresh) {
        _notifications = loaded;
      } else {
        _notifications.addAll(loaded);
      }
      _page++;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } on DioException catch (_) {} finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetches unread chat counts from all channels and adds them to the badge.
  Future<void> loadChatUnread() async {
    try {
      final res = await _api.get(ApiConstants.chatChannels);
      final items = res.data as List;
      _chatUnread = items.fold<int>(0, (sum, ch) => sum + ((ch['unreadCount'] ?? 0) as int));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(int id) async {
    try {
      await _api.put('${ApiConstants.notifications}/$id/read');
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        final n = _notifications[idx];
        _notifications[idx] = AppNotification(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          entityType: n.entityType,
          entityId: n.entityId,
          isRead: true,
          readAt: DateTime.now().toIso8601String(),
          createdAt: n.createdAt,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.put('${ApiConstants.notifications}/read-all');
      _notifications = _notifications.map((n) => AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            entityType: n.entityType,
            entityId: n.entityId,
            isRead: true,
            readAt: DateTime.now().toIso8601String(),
            createdAt: n.createdAt,
          )).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
