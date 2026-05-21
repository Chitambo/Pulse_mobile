import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

/// Stores paginated list responses keyed by (cacheKey, page).
/// e.g. cacheKey = "employees", "tickets_open", "clients"
class CachedLists extends Table {
  TextColumn get cacheKey => text()();
  IntColumn get page => integer().withDefault(const Constant(1))();
  TextColumn get jsonData => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey, page};
}

/// Stores individual item detail responses keyed by (entityType, entityId).
/// e.g. entityType = "ticket", entityId = 42
class CachedItems extends Table {
  TextColumn get entityType => text()();
  IntColumn get entityId => integer()();
  TextColumn get jsonData => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [CachedLists, CachedItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pulse_offline');
  }

  // ── CachedLists ──────────────────────────────────────────────────────────

  Future<CachedList?> getList(String key, {int page = 1}) {
    return (select(cachedLists)
          ..where((t) => t.cacheKey.equals(key) & t.page.equals(page)))
        .getSingleOrNull();
  }

  Future<void> upsertList(String key, int page, String json) {
    return into(cachedLists).insertOnConflictUpdate(CachedListsCompanion(
      cacheKey: Value(key),
      page: Value(page),
      jsonData: Value(json),
      cachedAt: Value(DateTime.now()),
    ));
  }

  Future<void> clearList(String key) {
    return (delete(cachedLists)..where((t) => t.cacheKey.equals(key))).go();
  }

  Future<void> clearAllLists() => delete(cachedLists).go();

  // ── CachedItems ──────────────────────────────────────────────────────────

  Future<CachedItem?> getItem(String type, int id) {
    return (select(cachedItems)
          ..where((t) => t.entityType.equals(type) & t.entityId.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertItem(String type, int id, String json) {
    return into(cachedItems).insertOnConflictUpdate(CachedItemsCompanion(
      entityType: Value(type),
      entityId: Value(id),
      jsonData: Value(json),
      cachedAt: Value(DateTime.now()),
    ));
  }
}
