import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';

/// The columns every task table had before the refactor, in order:
/// name, type and whether it is the primary key.
const expectedColumns = [
  ('key', 'TEXT', true),
  ('title', 'TEXT', false),
  ('category', 'TEXT', false),
  ('description', 'TEXT', false),
  ('image', 'TEXT', false),
  ('date', 'TEXT', false),
  ('time', 'TEXT', false),
  ('periority', 'TEXT', false),
  ('show', 'TEXT', false),
  ('progress', 'TEXT', false),
  ('status', 'TEXT', false),
];

TaskModel sampleTask(String key) => TaskModel(
      key: key,
      title: 'Comprar pão',
      category: 'Casa',
      description: 'Na padaria da esquina',
      image: 'assets/images/back2.jpg',
      priority: Priority.medium,
      time: '08:15 AM',
      date: '03 Nov 2026',
      show: 'yes',
      progress: '60',
      status: 'unComplete',
    );

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: DbHelper.schemaVersion,
      onCreate: DbHelper.createSchema,
    );
  });

  tearDown(() => db.close());

  test('a new database creates every task table with the same columns',
      () async {
    for (final table in ['Tasks', 'PendingUploads', 'PendingDeletes']) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');

      expect(
        [
          for (final c in columns)
            (c['name'] as String, c['type'] as String, c['pk'] == 1),
        ],
        expectedColumns,
        reason: table,
      );
    }
  });

  test('a task inserted in each table is read back with every field', () async {
    for (final table in DbHelper.taskTables) {
      final task = sampleTask('task-$table');
      await db.insert(table, task.toMap());

      final rows = await db.query(table);

      expect(rows, hasLength(1), reason: table);
      expect(TaskModel.fromMap(rows.single).toMap(), task.toMap(),
          reason: table);
    }
  });
}
