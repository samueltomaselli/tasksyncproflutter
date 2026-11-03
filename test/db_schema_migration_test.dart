import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';

/// The exact statement version 1 of the app ran: `time` and `status` have no
/// type and the trailing `,TEXT` created a column named TEXT.
String version1Table(String table) =>
    'CREATE TABLE $table(key TEXT PRIMARY KEY,title TEXT,category TEXT,'
    'description TEXT,image TEXT,date TEXT,time,periority TEXT,show TEXT,'
    'progress TEXT,status,TEXT)';

TaskModel savedTask(String key) => TaskModel(
      key: key,
      title: 'Saved before the update',
      category: 'Work',
      description: 'Description',
      image: 'assets/images/back2.jpg',
      periority: 'High',
      time: '09:30 AM',
      date: '10 Sep 2030',
      show: 'yes',
      progress: '40',
      status: 'unComplete',
    );

void main() {
  late Directory directory;
  late String path;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('db_migration');
    path = join(directory.path, 'db');

    final oldDb = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        for (final table in DbHelper.taskTables) {
          await db.execute(version1Table(table));
        }
      },
    );
    await oldDb.insert('Tasks', savedTask('task-1').toMap());
    await oldDb.insert('Tasks', savedTask('task-2').toMap());
    await oldDb.insert('PendingUploads', savedTask('pending-upload').toMap());
    await oldDb.insert('PendingDeletes', savedTask('pending-delete').toMap());
    await oldDb.close();
  });

  tearDown(() => directory.delete(recursive: true));

  Future<Database> openUpdatedApp() => openDatabase(
        path,
        version: DbHelper.schemaVersion,
        onCreate: DbHelper.createSchema,
        onUpgrade: DbHelper.upgradeSchema,
      );

  test('tasks saved in the old database are still there after the update',
      () async {
    final db = await openUpdatedApp();
    final helper = DbHelper(database: db);

    final tasks = await helper.getData();
    expect(tasks.map((t) => t.key), unorderedEquals(['task-1', 'task-2']));
    for (final task in tasks) {
      expect(task.toMap(), savedTask(task.key!).toMap());
    }

    final uploads = await helper.getPendingUploads();
    final deletes = await helper.getPendingDeletes();
    expect(uploads.single.toMap(), savedTask('pending-upload').toMap());
    expect(deletes.single.toMap(), savedTask('pending-delete').toMap());

    await db.close();
  });

  test('after the migration time and status are TEXT and TEXT is gone',
      () async {
    final db = await openUpdatedApp();

    for (final table in DbHelper.taskTables) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final types = {
        for (final c in columns) c['name'] as String: c['type'] as String,
      };
      expect(types['time'], 'TEXT', reason: table);
      expect(types['status'], 'TEXT', reason: table);
      expect(types.containsKey('TEXT'), isFalse, reason: table);
    }

    await db.close();
  });

  test('a new install already gets the corrected schema', () async {
    final freshPath = join(directory.path, 'fresh');
    final db = await openDatabase(
      freshPath,
      version: DbHelper.schemaVersion,
      onCreate: DbHelper.createSchema,
      onUpgrade: DbHelper.upgradeSchema,
    );

    final columns = await db.rawQuery('PRAGMA table_info(Tasks)');
    final names = columns.map((c) => c['name']).toList();
    expect(names, isNot(contains('TEXT')));
    expect(
      columns.firstWhere((c) => c['name'] == 'status')['type'],
      'TEXT',
    );

    await db.close();
  });
}
