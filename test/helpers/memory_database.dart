import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

class MemoryDatabase extends Fake implements Database {
  final Map<String, Map<String, Map<String, Object?>>> tables = {
    'Tasks': {},
    'PendingUploads': {},
    'PendingDeletes': {},
  };

  /// Tables whose writes throw, simulating a local SQLite failure.
  final Set<String> failingTables = {};

  void _throwIfFailing(String table) {
    if (failingTables.contains(table)) {
      throw StateError('local write failed: $table');
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return action(MemoryTransaction(this));
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _throwIfFailing(table);
    final key = values['key']! as String;
    if (tables[table]!.containsKey(key) &&
        conflictAlgorithm != ConflictAlgorithm.replace) {
      throw StateError('duplicate key: $key');
    }
    tables[table]![key] = Map<String, Object?>.from(values);
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _throwIfFailing(table);
    final key = whereArgs!.single! as String;
    if (!tables[table]!.containsKey(key)) return 0;
    tables[table]![key] = Map<String, Object?>.from(values);
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final key = whereArgs!.single! as String;
    return tables[table]!.remove(key) == null ? 0 : 1;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (whereArgs == null) {
      return tables[table]!
          .values
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }
    final row = tables[table]![whereArgs.single as String];
    return row == null ? [] : [Map<String, Object?>.from(row)];
  }
}

class MemoryTransaction extends Fake implements Transaction {
  MemoryTransaction(this.database);

  @override
  final MemoryDatabase database;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      database.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      database.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      database.delete(table, where: where, whereArgs: whereArgs);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      database.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
}
