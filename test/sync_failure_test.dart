// Covers what the user is told when a pending task cannot be uploaded:
// - HomeController.syncPendingUploads reports how many uploads failed and
//   leaves those tasks pending, while the ones that worked leave the queue.
// - When connectivity returns, a failed round reports the failures once,
//   a successful round reports nothing.
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
      periority: 'High',
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
