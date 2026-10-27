// Covers the "tasks waiting to sync" warning on the home screen:
// - PendingSyncBanner shows the right text, and nothing at all for zero.
// - HomeController.pendingCount counts the tasks sitting in PendingUploads.
// - When connectivity returns and the upload succeeds, the count drops to
//   zero (so the banner disappears). The upload is a no-op on this test host
//   because kUseFirebase is false on Linux.
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
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';
import 'package:to_do_app/view/home%20page/components/pending_sync_banner.dart';

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

  group('PendingSyncBanner', () {
    Future<void> pumpBanner(WidgetTester tester, int count) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PendingSyncBanner(count: count)),
      ));
    }

    testWidgets('shows nothing when no task is waiting', (tester) async {
      await pumpBanner(tester, 0);

      expect(find.byKey(const Key('pendingSyncBanner')), findsNothing);
      expect(find.textContaining('waiting to sync'), findsNothing);
    });

    testWidgets('uses the singular for one task', (tester) async {
      await pumpBanner(tester, 1);

      expect(find.text('1 task waiting to sync'), findsOneWidget);
    });

    testWidgets('shows the quantity for several tasks', (tester) async {
      await pumpBanner(tester, 3);

      expect(find.text('3 tasks waiting to sync'), findsOneWidget);
    });
  });

  group('HomeController.pendingCount', () {
    late Directory tempDir;
    late _FakeConnectivityPlatform connectivity;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pending_sync_test_');
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

    test('counts the tasks still waiting to be uploaded', () async {
      await _insertPending('offline-1');
      await _insertPending('offline-2');

      final controller = HomeController();
      await controller.getTaskData();

      expect(controller.pendingCount.value, 2);
    });

    test('is zero when every task is already on the server', () async {
      final controller = HomeController();
      await controller.getTaskData();

      expect(controller.pendingCount.value, 0);
    });

    test('drops to zero once connectivity returns and the upload succeeds',
        () async {
      await _insertPending('offline-1');
      final controller = HomeController();
      await controller.getTaskData();
      expect(controller.pendingCount.value, 1);

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => controller.pendingCount.value == 0);

      final helper = DbHelper();
      expect(await helper.getPendingUploads(), isEmpty);
      expect(
        (await helper.getData()).map((task) => task.key),
        contains('offline-1'),
      );
    });
  });
}
