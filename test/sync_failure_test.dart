// Covers what the user is told when a pending task cannot be uploaded:
// - HomeController.syncPendingUploads reports how many uploads failed and
//   leaves those tasks pending, while the ones that worked leave the queue.
// - When connectivity returns, a failed round reports the failures once,
//   a successful round reports nothing.
// - The warning is not repeated while the number of failed tasks stays the
//   same, and comes back when that number changes or after everything synced.
// - When pending tasks are uploaded, the user is told how many were synced.
// - Utils.showSyncFailed puts a message on screen saying the tasks are not
//   saved to the cloud yet.
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/utils/utils.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FakeConnectivityPlatform extends ConnectivityPlatform {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.none];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

TaskModel _task(String key) => TaskModel(
      key: key,
      title: 'Task $key',
      category: 'Work',
      description: 'Created offline',
      image: 'assets/images/back1.jpg',
      priority: Priority.high,
      time: '09:00 AM',
      date: '10 Sep 2026',
      show: 'yes',
      progress: '10',
      status: 'unComplete',
    );

Future<void> _insertPending(String key) async {
  final rawDb = await DbHelper().db;
  await rawDb!.insert('PendingUploads', _task(key).toMap());
}

/// A DbHelper whose uploads fail for every key in [failingKeys].
DbHelper _dbHelperFailingFor(Set<String> failingKeys) {
  return DbHelper(updateRemoteTask: (task) async {
    if (failingKeys.contains(task.key)) {
      throw Exception('no connection');
    }
  });
}

/// A DbHelper whose uploads fail for every key currently in [failingKeys]
/// and that counts every upload attempt in [attempts].
DbHelper _countingDbHelper(Set<String> failingKeys, List<String> attempts) {
  return DbHelper(updateRemoteTask: (task) async {
    attempts.add(task.key!);
    if (failingKeys.contains(task.key)) {
      throw Exception('no connection');
    }
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within 5 seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late _FakeConnectivityPlatform connectivity;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sync_failure_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    connectivity = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = connectivity;
    SharedPreferences.setMockInitialValues({
      'NAME': 'Test User',
      'EMAIL': 'test@example.com',
      'PASSWORD': 'secret',
      'NODE': 'test',
      'TOKEN': 'token-abc',
    });
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() async {
    Get.reset();
    await connectivity.changes.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('HomeController.syncPendingUploads', () {
    test('returns how many uploads failed and keeps those tasks pending',
        () async {
      await _insertPending('good');
      await _insertPending('bad');
      final controller = HomeController(dbHelper: _dbHelperFailingFor({'bad'}));

      final failed = await controller.syncPendingUploads();
      await controller.getTaskData();

      expect(failed, 1);
      final stillPending = await controller.db.getPendingUploads();
      expect(stillPending.map((task) => task.key), ['bad']);
      expect(controller.pendingCount.value, 1);
    });

    test('returns zero when every upload works', () async {
      await _insertPending('good');
      final controller = HomeController(dbHelper: _dbHelperFailingFor({}));

      expect(await controller.syncPendingUploads(), 0);
    });

    test('counts an upload that never answers as failed', () async {
      await _insertPending('slow');
      final controller = HomeController(
        dbHelper: DbHelper(
          updateRemoteTask: (task) => Completer<void>().future,
          uploadTimeout: const Duration(milliseconds: 50),
        ),
      );

      expect(await controller.syncPendingUploads(), 1);
      final stillPending = await controller.db.getPendingUploads();
      expect(stillPending.map((task) => task.key), ['slow']);
    });
  });

  group('after connectivity returns', () {
    test('reports the failed uploads once', () async {
      await _insertPending('bad-1');
      await _insertPending('bad-2');
      final reported = <int>[];
      final controller = HomeController(
        dbHelper: _dbHelperFailingFor({'bad-1', 'bad-2'}),
        syncFailedCallback: reported.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => reported.isNotEmpty);

      expect(reported, [2]);
      expect(controller.pendingCount.value, 2);
    });

    test('reports nothing when the uploads succeed', () async {
      await _insertPending('good');
      final reported = <int>[];
      final controller = HomeController(
        dbHelper: _dbHelperFailingFor({}),
        syncFailedCallback: reported.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.mobile]);
      await _waitFor(() => controller.pendingCount.value == 0);

      expect(reported, isEmpty);
    });

    test('shows one message even if connectivity flaps during the sync',
        () async {
      await _insertPending('bad');
      final reported = <int>[];
      final controller = HomeController(
        dbHelper: _dbHelperFailingFor({'bad'}),
        syncFailedCallback: reported.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      connectivity.changes.add([ConnectivityResult.mobile]);
      await _waitFor(() => reported.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(reported, [1]);
    });
  });

  group('repeated reconnections', () {
    test('shows one message when connectivity returns twice in a row',
        () async {
      await _insertPending('bad');
      final attempts = <String>[];
      final reported = <int>[];
      final controller = HomeController(
        dbHelper: _countingDbHelper({'bad'}, attempts),
        syncFailedCallback: reported.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => reported.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      connectivity.changes.add([ConnectivityResult.mobile]);
      await _waitFor(() => attempts.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(reported, [1]);
    });

    test('warns again when the number of failed tasks changes', () async {
      await _insertPending('bad-1');
      final attempts = <String>[];
      final reported = <int>[];
      final controller = HomeController(
        dbHelper: _countingDbHelper({'bad-1', 'bad-2'}, attempts),
        syncFailedCallback: reported.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => reported.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await _insertPending('bad-2');
      connectivity.changes.add([ConnectivityResult.mobile]);
      await _waitFor(() => reported.length == 2);

      expect(reported, [1, 2]);
    });

    test('warns again when a task fails after everything was synced', () async {
      await _insertPending('first');
      final failingKeys = {'first', 'second'};
      final attempts = <String>[];
      final reported = <int>[];
      final controller = HomeController(
        dbHelper: _countingDbHelper(failingKeys, attempts),
        syncFailedCallback: reported.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => reported.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      failingKeys.remove('first');
      connectivity.changes.add([ConnectivityResult.mobile]);
      await _waitFor(() => controller.pendingCount.value == 0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await _insertPending('second');
      connectivity.changes.add([ConnectivityResult.ethernet]);
      await _waitFor(() => reported.length == 2);

      expect(reported, [1, 1]);
    });
  });

  group('pending tasks sent after connectivity returns', () {
    test('tells how many pending tasks were synced', () async {
      await _insertPending('good-1');
      await _insertPending('good-2');
      final synced = <int>[];
      final failed = <int>[];
      final controller = HomeController(
        dbHelper: _dbHelperFailingFor({}),
        syncFailedCallback: failed.add,
        syncSucceededCallback: synced.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => synced.isNotEmpty);

      expect(synced, [2]);
      expect(failed, isEmpty);
    });

    test('says nothing when nothing was pending', () async {
      final synced = <int>[];
      final failed = <int>[];
      final controller = HomeController(
        dbHelper: _dbHelperFailingFor({}),
        syncFailedCallback: failed.add,
        syncSucceededCallback: synced.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(synced, isEmpty);
      expect(failed, isEmpty);
    });

    test('tells what was synced and what is still pending, without repeating',
        () async {
      await _insertPending('good-1');
      await _insertPending('good-2');
      await _insertPending('bad');
      final attempts = <String>[];
      final synced = <int>[];
      final failed = <int>[];
      final controller = HomeController(
        dbHelper: _countingDbHelper({'bad'}, attempts),
        syncFailedCallback: failed.add,
        syncSucceededCallback: synced.add,
      );
      await controller.getTaskData();

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => synced.isNotEmpty && failed.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      connectivity.changes.add([ConnectivityResult.mobile]);
      await _waitFor(() => attempts.length == 4);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(synced, [2]);
      expect(failed, [1]);
      expect(controller.pendingCount.value, 1);
    });
  });

  group('Utils.showSyncSucceeded', () {
    test('words the message for one task and for several', () {
      expect(Utils.syncedTasksMessage(1), '1 task synced to the cloud.');
      expect(Utils.syncedTasksMessage(2), '2 tasks synced to the cloud.');
    });

    testWidgets('shows the message on screen', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(
        home: Scaffold(body: SizedBox.expand()),
      ));

      Utils.showSyncSucceeded(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('2 tasks synced to the cloud.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('Utils.showSyncFailed', () {
    test('words the message for one task and for several', () {
      expect(
        Utils.unsyncedTasksMessage(1),
        startsWith('1 task is not saved to the cloud yet.'),
      );
      expect(
        Utils.unsyncedTasksMessage(3),
        startsWith('3 tasks are not saved to the cloud yet.'),
      );
    });

    testWidgets('shows the message on screen', (tester) async {
      await tester.pumpWidget(const GetMaterialApp(
        home: Scaffold(body: SizedBox.expand()),
      ));

      Utils.showSyncFailed(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Not synced'), findsOneWidget);
      expect(find.textContaining('2 tasks are not saved to the cloud yet'),
          findsOneWidget);

      // Let the snackbar time out and animate away before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
