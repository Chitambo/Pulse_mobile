import 'dart:convert';
import 'database.dart';

/// Singleton cache layer on top of the Drift database.
///
/// Cache-then-network pattern:
///   1. Call [getList] / [getItem] → returns decoded JSON if fresh.
///   2. Make the API call.
///   3. Call [saveList] / [saveItem] → persists for next launch.
class CacheStore {
  static final CacheStore _instance = CacheStore._();
  factory CacheStore() => _instance;
  CacheStore._();

  final _db = AppDatabase();

  /// How long before cached data is considered stale (still shown, but a
  /// background refresh is triggered).
  static const _staleAfter = Duration(minutes: 10);

  /// How long before cached data is considered expired (not shown at all).
  static const _expireAfter = Duration(hours: 24);

  // ── Lists ─────────────────────────────────────────────────────────────────

  /// Returns decoded JSON list if cached and not expired, null otherwise.
  Future<List<dynamic>?> getList(String key, {int page = 1}) async {
    final row = await _db.getList(key, page: page);
    if (row == null) return null;
    if (_isExpired(row.cachedAt)) return null;
    return jsonDecode(row.jsonData) as List<dynamic>;
  }

  /// Returns true if the cached list exists but is stale (needs refresh).
  Future<bool> isListStale(String key, {int page = 1}) async {
    final row = await _db.getList(key, page: page);
    if (row == null) return true;
    return _isStale(row.cachedAt);
  }

  Future<void> saveList(String key, int page, dynamic json) async {
    await _db.upsertList(key, page, jsonEncode(json));
  }

  Future<void> clearList(String key) => _db.clearList(key);

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getItem(String type, int id) async {
    final row = await _db.getItem(type, id);
    if (row == null) return null;
    if (_isExpired(row.cachedAt)) return null;
    return jsonDecode(row.jsonData) as Map<String, dynamic>;
  }

  Future<void> saveItem(String type, int id, dynamic json) async {
    await _db.upsertItem(type, id, jsonEncode(json));
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  /// Call on logout to wipe the entire cache.
  Future<void> clearAll() => _db.clearAllLists();

  bool _isStale(DateTime cachedAt) =>
      DateTime.now().difference(cachedAt) > _staleAfter;

  bool _isExpired(DateTime cachedAt) =>
      DateTime.now().difference(cachedAt) > _expireAfter;
}
