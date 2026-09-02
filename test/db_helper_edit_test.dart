import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';

class MemoryDatabase extends Fake implements Database {
  final Map<String, Map<String, Map<String, Object?>>> tables = {
    'Tasks': {},
    'PendingUploads': {},
    'PendingDeletes': {},
  };

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

TaskModel taskWithTitle(String title) => TaskModel(
      key: 'task-123',
      title: title,
      category: 'Work',
      description: 'Description',
      image: 'assets/images/back2.jpg',
      periority: 'Low',
      time: '09:30 AM',
      date: '10 Sep 2030',
      show: 'yes',
      progress: '50',
      status: 'unComplete',
    );

void main() {
  test('offline edit updates Tasks and keeps an outbox entry', () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    var remoteCalls = 0;
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (task) async => remoteCalls++,
    );

    await helper.updateAndSync(taskWithTitle('After'));

    expect(database.tables['Tasks']!['task-123']!['title'], 'After');
    expect(
      database.tables['PendingUploads']!['task-123']!['title'],
      'After',
    );
    expect(remoteCalls, 0);
  });

  test('editing an offline-created task updates its pending row', () async {
    final database = MemoryDatabase();
    await database.insert(
      'PendingUploads',
      taskWithTitle('Pending before').toMap(),
    );
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (_) async {},
    );

    await helper.updateAndSync(taskWithTitle('Pending after'));

    expect(database.tables['Tasks'], isEmpty);
    expect(
      database.tables['PendingUploads']!['task-123']!['title'],
      'Pending after',
    );
  });

  test('remote failure keeps the edited task queued for retry', () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async => throw StateError('remote unavailable'),
    );

    await helper.updateAndSync(taskWithTitle('After'));

    expect(database.tables['Tasks']!['task-123']!['title'], 'After');
    expect(
      database.tables['PendingUploads']!['task-123']!['title'],
      'After',
    );
  });

  test('successful online edit clears the outbox without a duplicate',
      () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    final remoteTasks = <TaskModel>[];
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (task) async => remoteTasks.add(task),
    );

    await helper.updateAndSync(taskWithTitle('After'));

    expect(database.tables['Tasks'], hasLength(1));
    expect(database.tables['Tasks']!['task-123']!['title'], 'After');
    expect(database.tables['PendingUploads'], isEmpty);
    expect(remoteTasks.single.key, 'task-123');
  });

  test('a queued edit is removed only after a successful retry', () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('After').toMap());
    await database.insert('PendingUploads', taskWithTitle('After').toMap());
    final remoteTasks = <TaskModel>[];
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (task) async => remoteTasks.add(task),
    );

    await helper.syncPendingUpload(taskWithTitle('After'));

    expect(database.tables['PendingUploads'], isEmpty);
    expect(database.tables['Tasks'], hasLength(1));
    expect(remoteTasks.single.title, 'After');
  });

  test('local tasks and pending edits are merged without duplicate keys',
      () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    await database.insert('PendingUploads', taskWithTitle('After').toMap());
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (_) async {},
    );

    final tasks = await helper.getDataWithPending();

    expect(tasks, hasLength(1));
    expect(tasks.single.key, 'task-123');
    expect(tasks.single.title, 'After');
  });

  test('deleting a task cancels its queued edit and queues only deletion',
      () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (_) async {},
    );
    await helper.updateAndSync(taskWithTitle('Edited offline'));
    final deleted = taskWithTitle('Edited offline')..show = 'no';

    await helper.removeFromList(deleted);

    expect(database.tables['Tasks']!['task-123']!['show'], 'no');
    expect(database.tables['PendingUploads'], isEmpty);
    expect(database.tables['PendingDeletes'], hasLength(1));
  });

  test('deleting an offline-created task removes it without remote deletion',
      () async {
    final database = MemoryDatabase();
    await database.insert(
      'PendingUploads',
      taskWithTitle('Never uploaded').toMap(),
    );
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (_) async {},
    );
    final deleted = taskWithTitle('Never uploaded')..show = 'no';

    await helper.removeFromList(deleted);

    expect(database.tables['Tasks'], isEmpty);
    expect(database.tables['PendingUploads'], isEmpty);
    expect(database.tables['PendingDeletes'], isEmpty);
  });

  test('an older retry cannot overwrite or dequeue a newer edit', () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    await database.insert('PendingUploads', taskWithTitle('Edit A').toMap());
    final remoteStarted = Completer<void>();
    final releaseRemote = Completer<void>();
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async {
        remoteStarted.complete();
        await releaseRemote.future;
      },
    );

    final retryA = helper.syncPendingUpload(taskWithTitle('Edit A'));
    await remoteStarted.future;
    await database.update(
      'Tasks',
      taskWithTitle('Edit B').toMap(),
      where: 'key = ?',
      whereArgs: ['task-123'],
    );
    await database.update(
      'PendingUploads',
      taskWithTitle('Edit B').toMap(),
      where: 'key = ?',
      whereArgs: ['task-123'],
    );
    releaseRemote.complete();

    await retryA;

    expect(database.tables['Tasks']!['task-123']!['title'], 'Edit B');
    expect(
      database.tables['PendingUploads']!['task-123']!['title'],
      'Edit B',
    );
  });

  test('a newer edit waits for an older retry and remains the final version',
      () async {
    final database = MemoryDatabase();
    await database.insert('Tasks', taskWithTitle('Before').toMap());
    await database.insert('PendingUploads', taskWithTitle('Edit A').toMap());
    final remoteStarted = Completer<void>();
    final releaseRemote = Completer<void>();
    final remoteTitles = <String?>[];
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (task) async {
        remoteTitles.add(task.title);
        if (task.title == 'Edit A') {
          remoteStarted.complete();
          await releaseRemote.future;
        }
      },
    );

    final retryA = helper.syncPendingUpload(taskWithTitle('Edit A'));
    await remoteStarted.future;
    final editB = helper.updateAndSync(taskWithTitle('Edit B'));
    releaseRemote.complete();
    await Future.wait([retryA, editB]);

    expect(remoteTitles, ['Edit A', 'Edit B']);
    expect(database.tables['Tasks']!['task-123']!['title'], 'Edit B');
    expect(database.tables['PendingUploads'], isEmpty);
  });

  test('deleting an offline-created task waits for its in-flight upload',
      () async {
    final database = MemoryDatabase();
    await database.insert(
      'PendingUploads',
      taskWithTitle('Uploading').toMap(),
    );
    final uploadStarted = Completer<void>();
    final releaseUpload = Completer<void>();
    var remoteDeletes = 0;
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async {
        uploadStarted.complete();
        await releaseUpload.future;
      },
      deleteRemoteTask: (_) async => remoteDeletes++,
    );

    final upload = helper.syncPendingUpload(taskWithTitle('Uploading'));
    await uploadStarted.future;
    final deleted = taskWithTitle('Uploading')..show = 'no';
    final deletion = helper.removeFromList(deleted);
    releaseUpload.complete();
    await Future.wait([upload, deletion]);

    expect(remoteDeletes, 1);
    expect(database.tables['Tasks']!['task-123']!['show'], 'no');
    expect(database.tables['PendingUploads'], isEmpty);
    expect(database.tables['PendingDeletes'], isEmpty);
  });

  test('pending deletion is removed only after remote confirmation', () async {
    final database = MemoryDatabase();
    final deleted = taskWithTitle('Deleted')..show = 'no';
    await database.insert('PendingDeletes', deleted.toMap());
    final failingHelper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async {},
      deleteRemoteTask: (_) async => throw StateError('remote unavailable'),
    );

    await expectLater(
      failingHelper.syncPendingDelete(deleted),
      throwsA(isA<StateError>()),
    );
    expect(database.tables['PendingDeletes'], hasLength(1));

    final successfulHelper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async {},
      deleteRemoteTask: (_) async {},
    );
    await successfulHelper.syncPendingDelete(deleted);

    expect(database.tables['PendingDeletes'], isEmpty);
  });
}
