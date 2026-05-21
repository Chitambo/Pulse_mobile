// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CachedListsTable extends CachedLists
    with TableInfo<$CachedListsTable, CachedList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _jsonDataMeta = const VerificationMeta(
    'jsonData',
  );
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
    'json_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, page, jsonData, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    }
    if (data.containsKey('json_data')) {
      context.handle(
        _jsonDataMeta,
        jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey, page};
  @override
  CachedList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedList(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      jsonData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_data'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedListsTable createAlias(String alias) {
    return $CachedListsTable(attachedDatabase, alias);
  }
}

class CachedList extends DataClass implements Insertable<CachedList> {
  final String cacheKey;
  final int page;
  final String jsonData;
  final DateTime cachedAt;
  const CachedList({
    required this.cacheKey,
    required this.page,
    required this.jsonData,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['page'] = Variable<int>(page);
    map['json_data'] = Variable<String>(jsonData);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedListsCompanion toCompanion(bool nullToAbsent) {
    return CachedListsCompanion(
      cacheKey: Value(cacheKey),
      page: Value(page),
      jsonData: Value(jsonData),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedList(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      page: serializer.fromJson<int>(json['page']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'page': serializer.toJson<int>(page),
      'jsonData': serializer.toJson<String>(jsonData),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedList copyWith({
    String? cacheKey,
    int? page,
    String? jsonData,
    DateTime? cachedAt,
  }) => CachedList(
    cacheKey: cacheKey ?? this.cacheKey,
    page: page ?? this.page,
    jsonData: jsonData ?? this.jsonData,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedList copyWithCompanion(CachedListsCompanion data) {
    return CachedList(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      page: data.page.present ? data.page.value : this.page,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedList(')
          ..write('cacheKey: $cacheKey, ')
          ..write('page: $page, ')
          ..write('jsonData: $jsonData, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, page, jsonData, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedList &&
          other.cacheKey == this.cacheKey &&
          other.page == this.page &&
          other.jsonData == this.jsonData &&
          other.cachedAt == this.cachedAt);
}

class CachedListsCompanion extends UpdateCompanion<CachedList> {
  final Value<String> cacheKey;
  final Value<int> page;
  final Value<String> jsonData;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedListsCompanion({
    this.cacheKey = const Value.absent(),
    this.page = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedListsCompanion.insert({
    required String cacheKey,
    this.page = const Value.absent(),
    required String jsonData,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       jsonData = Value(jsonData),
       cachedAt = Value(cachedAt);
  static Insertable<CachedList> custom({
    Expression<String>? cacheKey,
    Expression<int>? page,
    Expression<String>? jsonData,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (page != null) 'page': page,
      if (jsonData != null) 'json_data': jsonData,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedListsCompanion copyWith({
    Value<String>? cacheKey,
    Value<int>? page,
    Value<String>? jsonData,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedListsCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      page: page ?? this.page,
      jsonData: jsonData ?? this.jsonData,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedListsCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('page: $page, ')
          ..write('jsonData: $jsonData, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedItemsTable extends CachedItems
    with TableInfo<$CachedItemsTable, CachedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonDataMeta = const VerificationMeta(
    'jsonData',
  );
  @override
  late final GeneratedColumn<String> jsonData = GeneratedColumn<String>(
    'json_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entityType,
    entityId,
    jsonData,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('json_data')) {
      context.handle(
        _jsonDataMeta,
        jsonData.isAcceptableOrUnknown(data['json_data']!, _jsonDataMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonDataMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType, entityId};
  @override
  CachedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedItem(
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_id'],
      )!,
      jsonData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_data'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedItemsTable createAlias(String alias) {
    return $CachedItemsTable(attachedDatabase, alias);
  }
}

class CachedItem extends DataClass implements Insertable<CachedItem> {
  final String entityType;
  final int entityId;
  final String jsonData;
  final DateTime cachedAt;
  const CachedItem({
    required this.entityType,
    required this.entityId,
    required this.jsonData,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<int>(entityId);
    map['json_data'] = Variable<String>(jsonData);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedItemsCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      jsonData: Value(jsonData),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedItem(
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<int>(json['entityId']),
      jsonData: serializer.fromJson<String>(json['jsonData']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<int>(entityId),
      'jsonData': serializer.toJson<String>(jsonData),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedItem copyWith({
    String? entityType,
    int? entityId,
    String? jsonData,
    DateTime? cachedAt,
  }) => CachedItem(
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    jsonData: jsonData ?? this.jsonData,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedItem copyWithCompanion(CachedItemsCompanion data) {
    return CachedItem(
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      jsonData: data.jsonData.present ? data.jsonData.value : this.jsonData,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedItem(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('jsonData: $jsonData, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityType, entityId, jsonData, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedItem &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.jsonData == this.jsonData &&
          other.cachedAt == this.cachedAt);
}

class CachedItemsCompanion extends UpdateCompanion<CachedItem> {
  final Value<String> entityType;
  final Value<int> entityId;
  final Value<String> jsonData;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedItemsCompanion({
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.jsonData = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedItemsCompanion.insert({
    required String entityType,
    required int entityId,
    required String jsonData,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       jsonData = Value(jsonData),
       cachedAt = Value(cachedAt);
  static Insertable<CachedItem> custom({
    Expression<String>? entityType,
    Expression<int>? entityId,
    Expression<String>? jsonData,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (jsonData != null) 'json_data': jsonData,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedItemsCompanion copyWith({
    Value<String>? entityType,
    Value<int>? entityId,
    Value<String>? jsonData,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedItemsCompanion(
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      jsonData: jsonData ?? this.jsonData,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (jsonData.present) {
      map['json_data'] = Variable<String>(jsonData.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedItemsCompanion(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('jsonData: $jsonData, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedListsTable cachedLists = $CachedListsTable(this);
  late final $CachedItemsTable cachedItems = $CachedItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedLists,
    cachedItems,
  ];
}

typedef $$CachedListsTableCreateCompanionBuilder =
    CachedListsCompanion Function({
      required String cacheKey,
      Value<int> page,
      required String jsonData,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedListsTableUpdateCompanionBuilder =
    CachedListsCompanion Function({
      Value<String> cacheKey,
      Value<int> page,
      Value<String> jsonData,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedListsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedListsTable> {
  $$CachedListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedListsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedListsTable> {
  $$CachedListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedListsTable> {
  $$CachedListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedListsTable,
          CachedList,
          $$CachedListsTableFilterComposer,
          $$CachedListsTableOrderingComposer,
          $$CachedListsTableAnnotationComposer,
          $$CachedListsTableCreateCompanionBuilder,
          $$CachedListsTableUpdateCompanionBuilder,
          (
            CachedList,
            BaseReferences<_$AppDatabase, $CachedListsTable, CachedList>,
          ),
          CachedList,
          PrefetchHooks Function()
        > {
  $$CachedListsTableTableManager(_$AppDatabase db, $CachedListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<String> jsonData = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedListsCompanion(
                cacheKey: cacheKey,
                page: page,
                jsonData: jsonData,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                Value<int> page = const Value.absent(),
                required String jsonData,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedListsCompanion.insert(
                cacheKey: cacheKey,
                page: page,
                jsonData: jsonData,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedListsTable,
      CachedList,
      $$CachedListsTableFilterComposer,
      $$CachedListsTableOrderingComposer,
      $$CachedListsTableAnnotationComposer,
      $$CachedListsTableCreateCompanionBuilder,
      $$CachedListsTableUpdateCompanionBuilder,
      (
        CachedList,
        BaseReferences<_$AppDatabase, $CachedListsTable, CachedList>,
      ),
      CachedList,
      PrefetchHooks Function()
    >;
typedef $$CachedItemsTableCreateCompanionBuilder =
    CachedItemsCompanion Function({
      required String entityType,
      required int entityId,
      required String jsonData,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedItemsTableUpdateCompanionBuilder =
    CachedItemsCompanion Function({
      Value<String> entityType,
      Value<int> entityId,
      Value<String> jsonData,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedItemsTable> {
  $$CachedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedItemsTable> {
  $$CachedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonData => $composableBuilder(
    column: $table.jsonData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedItemsTable> {
  $$CachedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get jsonData =>
      $composableBuilder(column: $table.jsonData, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedItemsTable,
          CachedItem,
          $$CachedItemsTableFilterComposer,
          $$CachedItemsTableOrderingComposer,
          $$CachedItemsTableAnnotationComposer,
          $$CachedItemsTableCreateCompanionBuilder,
          $$CachedItemsTableUpdateCompanionBuilder,
          (
            CachedItem,
            BaseReferences<_$AppDatabase, $CachedItemsTable, CachedItem>,
          ),
          CachedItem,
          PrefetchHooks Function()
        > {
  $$CachedItemsTableTableManager(_$AppDatabase db, $CachedItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entityType = const Value.absent(),
                Value<int> entityId = const Value.absent(),
                Value<String> jsonData = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedItemsCompanion(
                entityType: entityType,
                entityId: entityId,
                jsonData: jsonData,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityType,
                required int entityId,
                required String jsonData,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedItemsCompanion.insert(
                entityType: entityType,
                entityId: entityId,
                jsonData: jsonData,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedItemsTable,
      CachedItem,
      $$CachedItemsTableFilterComposer,
      $$CachedItemsTableOrderingComposer,
      $$CachedItemsTableAnnotationComposer,
      $$CachedItemsTableCreateCompanionBuilder,
      $$CachedItemsTableUpdateCompanionBuilder,
      (
        CachedItem,
        BaseReferences<_$AppDatabase, $CachedItemsTable, CachedItem>,
      ),
      CachedItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedListsTableTableManager get cachedLists =>
      $$CachedListsTableTableManager(_db, _db.cachedLists);
  $$CachedItemsTableTableManager get cachedItems =>
      $$CachedItemsTableTableManager(_db, _db.cachedItems);
}
