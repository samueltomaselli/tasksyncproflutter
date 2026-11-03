import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';

import 'helpers/memory_database.dart';

TaskModel newTask() => TaskModel(
      key: 'new-task',
      title: 'Created offline',
      category: 'Work',
      description: 'Description',
      image: 'assets/images/back2.jpg',
      periority: 'Medium',
      time: '09:30 AM',
      date: '10 Sep 2030',
      show: 'yes',
      progress: '0',
      status: 'unComplete',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'a task created on Wi-Fi without internet stays pending until it uploads',
      () async {
    final database = MemoryDatabase();
    final offlineHelper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async => throw StateError('no internet'),
    );

    await offlineHelper.insert(newTask());

    expect(database.tables['PendingUploads']!.keys, ['new-task']);
    expect(database.tables['Tasks'], isEmpty);

    final uploaded = <TaskModel>[];
    final onlineHelper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (task) async => uploaded.add(task),
    );
    await onlineHelper.syncPendingUpload(newTask());

    expect(uploaded.single.key, 'new-task');
    expect(database.tables['PendingUploads'], isEmpty);
    expect(database.tables['Tasks']!.keys, ['new-task']);
  });

  test('a task whose upload failed is still listed after reopening the app',
      () async {
    final database = MemoryDatabase();
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async => throw StateError('upload dropped'),
    );
    await helper.insert(newTask());

    final reopened = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (_) async {},
    );
    final tasks = await reopened.getDataWithPending();

    expect(tasks.map((task) => task.key), ['new-task']);
    expect(await reopened.getPendingUploads(), hasLength(1));
  });

  test('a task created offline is queued without calling the server', () async {
    final database = MemoryDatabase();
    var remoteCalls = 0;
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.none],
      updateRemoteTask: (_) async => remoteCalls++,
    );

    await helper.insert(newTask());

    expect(database.tables['PendingUploads']!.keys, ['new-task']);
    expect(database.tables['Tasks'], isEmpty);
    expect(remoteCalls, 0);
  });

  test('a task created online is uploaded and leaves the queue empty',
      () async {
    final database = MemoryDatabase();
    final uploaded = <TaskModel>[];
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.mobile],
      updateRemoteTask: (task) async => uploaded.add(task),
    );

    await helper.insert(newTask());

    expect(uploaded.single.key, 'new-task');
    expect(database.tables['Tasks']!.keys, ['new-task']);
    expect(database.tables['PendingUploads'], isEmpty);
  });

  test('a task created over ethernet is uploaded like on Wi-Fi', () async {
    final database = MemoryDatabase();
    final uploaded = <TaskModel>[];
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.ethernet],
      updateRemoteTask: (task) async => uploaded.add(task),
    );

    await helper.insert(newTask());

    expect(uploaded.single.key, 'new-task');
    expect(database.tables['PendingUploads'], isEmpty);
  });

  test('a local write failure is reported to the caller', () async {
    final database = MemoryDatabase()
      ..failingTables.addAll(['Tasks', 'PendingUploads']);
    var remoteCalls = 0;
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async => remoteCalls++,
    );

    await expectLater(helper.insert(newTask()), throwsA(isA<StateError>()));
    expect(remoteCalls, 0);
  });

  test('an upload that never answers does not block task creation', () async {
    final database = MemoryDatabase();
    final neverAnswers = Completer<void>();
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) => neverAnswers.future,
      uploadTimeout: const Duration(milliseconds: 10),
    );

    await helper.insert(newTask());

    expect(database.tables['PendingUploads']!.keys, ['new-task']);
    expect(database.tables['Tasks'], isEmpty);
  });

  test('a task received from the server is cached without uploading again',
      () async {
    final database = MemoryDatabase();
    var remoteCalls = 0;
    final helper = DbHelper(
      database: database,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      updateRemoteTask: (_) async => remoteCalls++,
    );

    await helper.saveRemoteTask(newTask());

    expect(database.tables['Tasks']!.keys, ['new-task']);
    expect(database.tables['PendingUploads'], isEmpty);
    expect(remoteCalls, 0);
  });
}
