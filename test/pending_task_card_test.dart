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
import 'package:to_do_app/view/home%20page/components/progress_container.dart';

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
      description: 'Created for the card test',
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

Future<void> _insertSynced(String key) async {
  final rawDb = await DbHelper().db;
  await rawDb!.insert('Tasks', _task(key).toMap());
}

Widget _hostCard(Widget card) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
          ),
          child: card,
        ),
      ),
    ),
  );
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
    tempDir = Directory.systemTemp.createTempSync('pending_task_card_test_');
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
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // On Windows SQLite may still hold the file open. The folder is only
        // scratch space in the system temp directory, so leave it behind.
      }
    }
  });

  group('HomeController.pendingKeys', () {
    test('holds only the keys of tasks waiting for upload', () async {
      await _insertPending('offline-1');
      await _insertPending('offline-2');
      await _insertSynced('on-server');

      final controller = HomeController();
      await controller.getTaskData();

      expect(controller.pendingKeys.toSet(), {'offline-1', 'offline-2'});
      expect(controller.list.length, 3);
    });

    test('is empty when every task is already on the server', () async {
      await _insertSynced('on-server');

      final controller = HomeController();
      await controller.getTaskData();

      expect(controller.pendingKeys, isEmpty);
    });

    test('marks a sent task as pending again when edited offline', () async {
      await _insertSynced('on-server');
      final controller = HomeController(
        dbHelper: DbHelper(
          checkConnectivity: () async => [ConnectivityResult.none],
        ),
      );
      await controller.getTaskData();
      expect(controller.pendingKeys, isEmpty);

      await controller.db.updateAndSync(_task('on-server')..title = 'Edited');
      await controller.getTaskData();

      expect(controller.pendingKeys.toSet(), {'on-server'});
    });

    test('keeps the key of a task whose upload failed', () async {
      await _insertPending('good');
      await _insertPending('bad');
      final controller = HomeController(
        dbHelper: DbHelper(updateRemoteTask: (task) async {
          if (task.key == 'bad') throw Exception('no connection');
        }),
      );

      await controller.syncPendingUploads();
      await controller.getTaskData();

      expect(controller.pendingKeys.toSet(), {'bad'});
    });

    test('drops the keys once the upload succeeds on reconnect', () async {
      await _insertPending('offline-1');
      final controller = HomeController();
      await controller.getTaskData();
      expect(controller.pendingKeys.toSet(), {'offline-1'});

      connectivity.changes.add([ConnectivityResult.wifi]);
      await _waitFor(() => controller.pendingKeys.isEmpty);

      expect(controller.pendingCount.value, 0);
    });
  });

  group('ProgressContainer', () {
    const pendingIcon = Icons.cloud_upload_outlined;

    Future<HomeController> pumpCard(WidgetTester tester, String key) async {
      late HomeController controller;
      await tester.runAsync(() async {
        controller = HomeController();
        await controller.getTaskData();
      });
      final index = controller.list.indexWhere((task) => task.key == key);
      await tester.pumpWidget(_hostCard(
        ProgressContainer(index: index, controller: controller),
      ));
      return controller;
    }

    testWidgets('shows a task not yet on the server as waiting',
        (tester) async {
      await tester.runAsync(() => _insertPending('offline-1'));

      await pumpCard(tester, 'offline-1');

      expect(find.byIcon(pendingIcon), findsOneWidget);
      expect(find.byTooltip('Aguardando envio'), findsOneWidget);
    });

    testWidgets('shows no mark for a task that was already sent',
        (tester) async {
      await tester.runAsync(() => _insertSynced('on-server'));

      await pumpCard(tester, 'on-server');

      expect(find.byIcon(pendingIcon), findsNothing);
      expect(find.byTooltip('Aguardando envio'), findsNothing);
    });

    testWidgets('marks only the pending card when both kinds exist',
        (tester) async {
      await tester.runAsync(() async {
        await _insertPending('offline-1');
        await _insertSynced('on-server');
      });
      late HomeController controller;
      await tester.runAsync(() async {
        controller = HomeController();
        await controller.getTaskData();
      });
      await tester.pumpWidget(_hostCard(
        Row(
          children: [
            for (var i = 0; i < controller.list.length; i++)
              ProgressContainer(index: i, controller: controller),
          ],
        ),
      ));

      expect(find.byIcon(pendingIcon), findsOneWidget);
    });

    testWidgets('removes the mark when the upload finishes on the screen',
        (tester) async {
      await tester.runAsync(() => _insertPending('offline-1'));
      final controller = await pumpCard(tester, 'offline-1');
      expect(find.byIcon(pendingIcon), findsOneWidget);

      await tester.runAsync(() async {
        await controller.syncPendingUploads();
        await controller.getTaskData();
      });
      await tester.pump();

      expect(find.byIcon(pendingIcon), findsNothing);
    });
  });
}
