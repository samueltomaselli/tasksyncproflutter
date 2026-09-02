import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:to_do_app/model/task_model.dart';
import '../../data/network/firebase/firebase_services.dart';

typedef ConnectivityChecker = Future<List<ConnectivityResult>> Function();
typedef RemoteTaskUpdate = Future<void> Function(TaskModel task);
typedef RemoteTaskDelete = Future<void> Function(TaskModel task);

class DbHelper {
  DbHelper({
    Database? database,
    ConnectivityChecker? checkConnectivity,
    RemoteTaskUpdate? updateRemoteTask,
    RemoteTaskDelete? deleteRemoteTask,
  })  : _db = database,
        _checkConnectivity =
            checkConnectivity ?? (() => Connectivity().checkConnectivity()),
        _updateRemoteTask = updateRemoteTask ?? FirebaseService.updateTask,
        _deleteRemoteTask = deleteRemoteTask ??
            ((task) => FirebaseService.update(task.key!, 'show', 'no'));

  Database? _db;
  final ConnectivityChecker _checkConnectivity;
  final RemoteTaskUpdate _updateRemoteTask;
  final RemoteTaskDelete _deleteRemoteTask;
  static final Map<String, Future<void>> _keyOperations = {};

  Future<T> _withKeyLock<T>(String key, Future<T> Function() operation) async {
    final previous = _keyOperations[key] ?? Future<void>.value();
    final current = Completer<void>();
    _keyOperations[key] = current.future;
    try {
      try {
        await previous;
      } catch (_) {
        // A failed operation must not prevent the next queued operation.
      }
      return await operation();
    } finally {
      current.complete();
      if (identical(_keyOperations[key], current.future)) {
        _keyOperations.remove(key);
      }
    }
  }

  Future<Database?> get db async {
    if (_db != null) {
      return _db;
    }
    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationSupportDirectory();
    String path = join(directory!.path, 'db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute(
            "CREATE TABLE Tasks(key TEXT PRIMARY KEY,title TEXT,category TEXT,description TEXT,image TEXT,date TEXT,time,periority TEXT,show TEXT,progress TEXT,status,TEXT)");
        db.execute(
            "CREATE TABLE PendingUploads(key TEXT PRIMARY KEY,title TEXT,category TEXT,description TEXT,image TEXT,date TEXT,time,periority TEXT,show TEXT,progress TEXT,status,TEXT)");
        db.execute(
            "CREATE TABLE PendingDeletes(key TEXT PRIMARY KEY,title TEXT,category TEXT,description TEXT,image TEXT,date TEXT,time,periority TEXT,show TEXT,progress TEXT,status,TEXT)");
      },
    );
    return _db;
  }

  Future<TaskModel> insert(TaskModel model) async {
    var dbClient = await db;
    final Connectivity connectivity = Connectivity();
    var connection = await connectivity.checkConnectivity();
    if (connection.contains(ConnectivityResult.wifi) ||
        connection.contains(ConnectivityResult.mobile)) {
      dbClient!.insert('Tasks', model.toMap()).then(
        (value) {
          FirebaseService.insertData(model);
        },
      ).onError(
        (error, stackTrace) {},
      );

      return model;
    }
    dbClient!.insert('PendingUploads', model.toMap()).then((value) {});

    return model;
  }

  Future<void> removeFromList(TaskModel model) async {
    await _withKeyLock(model.key!, () => _removeFromList(model));
  }

  Future<void> _removeFromList(TaskModel model) async {
    final dbClient = await db;
    final key = model.key!;
    final needsRemoteDelete = await dbClient!.transaction((transaction) async {
      final taskRows = await transaction.query(
        'Tasks',
        where: 'key = ?',
        whereArgs: [key],
      );
      final pendingRows = await transaction.query(
        'PendingUploads',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (taskRows.isEmpty && pendingRows.isNotEmpty) {
        await transaction.delete(
          'PendingUploads',
          where: 'key = ?',
          whereArgs: [key],
        );
        return false;
      }
      if (taskRows.isEmpty) return false;

      await transaction.update(
        'Tasks',
        {'show': 'no'},
        where: 'key = ?',
        whereArgs: [key],
      );
      await transaction.delete(
        'PendingUploads',
        where: 'key = ?',
        whereArgs: [key],
      );
      await transaction.insert(
        'PendingDeletes',
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    });
    if (!needsRemoteDelete) return;

    final connection = await _checkConnectivity();
    final isOnline = connection.contains(ConnectivityResult.wifi) ||
        connection.contains(ConnectivityResult.mobile) ||
        connection.contains(ConnectivityResult.ethernet);
    if (isOnline) {
      try {
        await _deleteRemoteTask(model);
        await dbClient.delete(
          'PendingDeletes',
          where: 'key = ?',
          whereArgs: [key],
        );
        return;
      } catch (_) {
        // Queue the deletion below so it can be retried.
      }
    }
  }

  Future<void> update(TaskModel model) async {
    var dbClient = await db;
    await dbClient!.update('Tasks', model.toMap(),
        where: 'key = ?', whereArgs: [model.key!]);
  }

  Future<void> updateAndSync(TaskModel model) async {
    await _withKeyLock(model.key!, () => _updateAndSync(model));
  }

  Future<void> _updateAndSync(TaskModel model) async {
    final dbClient = await db;
    final key = model.key!;
    await dbClient!.transaction((transaction) async {
      final pendingRows = await transaction.query(
        'PendingUploads',
        where: 'key = ?',
        whereArgs: [key],
      );
      final taskRows = await transaction.query(
        'Tasks',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (pendingRows.isNotEmpty && taskRows.isEmpty) {
        await transaction.update(
          'PendingUploads',
          model.toMap(),
          where: 'key = ?',
          whereArgs: [key],
        );
      } else if (taskRows.isNotEmpty) {
        await transaction.update(
          'Tasks',
          model.toMap(),
          where: 'key = ?',
          whereArgs: [key],
        );
        await transaction.insert(
          'PendingUploads',
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        throw StateError('Task $key was not found locally');
      }
    });

    final connection = await _checkConnectivity();
    final isOnline = connection.contains(ConnectivityResult.wifi) ||
        connection.contains(ConnectivityResult.mobile) ||
        connection.contains(ConnectivityResult.ethernet);
    if (!isOnline) return;

    try {
      await _syncPendingUpload(model);
    } catch (_) {
      // The local edit remains in PendingUploads and will be retried when the
      // connectivity listener fires again.
    }
  }

  Future<void> syncPendingUpload(TaskModel model) async {
    await _withKeyLock(model.key!, () => _syncPendingUpload(model));
  }

  Future<void> _syncPendingUpload(TaskModel model) async {
    final dbClient = await db;
    final key = model.key!;
    await _updateRemoteTask(model);

    final pendingRows = await dbClient!.query(
      'PendingUploads',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (pendingRows.isEmpty || !mapEquals(pendingRows.single, model.toMap())) {
      return;
    }

    final taskRows = await dbClient.query(
      'Tasks',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (taskRows.isEmpty) {
      await dbClient.insert(
        'Tasks',
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await dbClient.update(
        'Tasks',
        model.toMap(),
        where: 'key = ?',
        whereArgs: [key],
      );
    }
    await dbClient.delete(
      'PendingUploads',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  Future<void> syncPendingDelete(TaskModel model) async {
    await _withKeyLock(model.key!, () => _syncPendingDelete(model));
  }

  Future<void> _syncPendingDelete(TaskModel model) async {
    final dbClient = await db;
    await _deleteRemoteTask(model);
    await dbClient!.delete(
      'PendingDeletes',
      where: 'key = ?',
      whereArgs: [model.key!],
    );
  }

  Future<int> delete(String id, String table) async {
    var dbClient = await db;
    return await dbClient!.delete(table, where: 'key = ?', whereArgs: [id]);
  }

  Future<List<TaskModel>> getData() async {
    var dbClient = await db;
    final List<Map<String, Object?>> queryResult =
        await dbClient!.query('Tasks');
    return queryResult.map((e) => TaskModel.fromMap(e)).toList();
  }

  Future<List<TaskModel>> getPendingUploads() async {
    var dbClient = await db;
    final List<Map<String, Object?>> queryResult =
        await dbClient!.query('PendingUploads');
    return queryResult.map((e) => TaskModel.fromMap(e)).toList();
  }

  Future<List<TaskModel>> getDataWithPending() async {
    final tasksByKey = <String, TaskModel>{};
    for (final task in await getData()) {
      tasksByKey[task.key!] = task;
    }
    for (final pendingTask in await getPendingUploads()) {
      tasksByKey[pendingTask.key!] = pendingTask;
    }
    return tasksByKey.values.toList();
  }

  Future<List<TaskModel>> getPendingDeletes() async {
    var dbClient = await db;
    final List<Map<String, Object?>> queryResult =
        await dbClient!.query('PendingDeletes');
    return queryResult.map((e) => TaskModel.fromMap(e)).toList();
  }

  Future<bool> isRowExists(String id, String table) async {
    var dbClient = await db;
    var count = await dbClient!.query(table, where: 'key = ?', whereArgs: [id]);

    return count.isNotEmpty;
  }

  Future<void> clearAllData() async {
    final dbClient = await db;
    await dbClient!.delete('Tasks');
    await dbClient.delete('PendingUploads');
    await dbClient.delete('PendingDeletes');
  }
}
