// Covers what happens when the user taps "Logout" while tasks may still be
// waiting to be uploaded:
// - nothing pending: a plain confirmation, then logout.
// - pending: a warning with the quantity; cancelling keeps everything.
// - pending and offline: logout goes ahead without trying to upload.
// - pending and online: the uploads run first, before the data is cleared.
//   If some still fail (or take too long) the user is asked once more and
//   can stay or leave anyway.
// The database work runs on real I/O, so each step lets real time pass
// (tester.runAsync) and then pumps the frames it triggered.
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
import 'package:to_do_app/view/home%20page/components/logout_flow.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _FakeConnectivityPlatform extends ConnectivityPlatform {
  List<ConnectivityResult> current = [ConnectivityResult.wifi];
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

/// Records the logout instead of clearing data and navigating, and notes how
/// many tasks were still pending at that moment.
class _RecordingController extends HomeController {
  _RecordingController({super.dbHelper, super.logoutSyncTimeout});

  int logoutCalls = 0;
  int? pendingWhenLoggedOut;

  @override
  Future<void> logout() async {
    logoutCalls++;
    pendingWhenLoggedOut = await countPendingUploads();
  }
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

Future<void> _insertPending(WidgetTester tester, List<String> keys) {
  return tester.runAsync(() async {
    final rawDb = await DbHelper().db;
    for (final key in keys) {
      await rawDb!.insert('PendingUploads', _task(key).toMap());
    }
  });
}

/// Lets real async work finish, then pumps the frames it triggered.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
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
  late List<String> uploaded;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('logout_flow_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    connectivity = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = connectivity;
    uploaded = [];
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

  tearDown(() {
    Get.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// A remote that fails for [failingKeys], never answers for [stuckKeys]
  /// and otherwise records the upload.
  DbHelper dbHelper({
    Set<String> failingKeys = const {},
    Set<String> stuckKeys = const {},
  }) {
    return DbHelper(updateRemoteTask: (task) {
      if (stuckKeys.contains(task.key)) return Completer<void>().future;
      if (failingKeys.contains(task.key)) {
        return Future<void>.error(Exception('no connection'));
      }
      uploaded.add(task.key!);
      return Future<void>.value();
    });
  }

  Future<void> startLogout(
      WidgetTester tester, HomeController controller) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => confirmAndLogout(context, controller),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.text('Start'));
    await _settle(tester);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(TextButton, label));
    await _settle(tester);
  }

  testWidgets('without pending tasks it only asks for a plain confirmation',
      (tester) async {
    final controller = _RecordingController(dbHelper: dbHelper());

    await startLogout(tester, controller);

    expect(find.text('Are you sure you want to logout?'), findsOneWidget);
    expect(find.text('Unsynced tasks'), findsNothing);

    await tapButton(tester, 'Logout');

    expect(controller.logoutCalls, 1);
    expect(uploaded, isEmpty);
  });

  testWidgets('cancelling the plain confirmation keeps the session',
      (tester) async {
    final controller = _RecordingController(dbHelper: dbHelper());

    await startLogout(tester, controller);
    await tapButton(tester, 'Cancel');

    expect(controller.logoutCalls, 0);
  });

  testWidgets('with pending tasks it warns how many will be lost',
      (tester) async {
    await _insertPending(tester, ['a', 'b']);
    final controller = _RecordingController(dbHelper: dbHelper());

    await startLogout(tester, controller);

    expect(find.text('Unsynced tasks'), findsOneWidget);
    expect(find.text(unsyncedLogoutMessage(2)), findsOneWidget);
    expect(find.text('Are you sure you want to logout?'), findsNothing);
  });

  testWidgets('cancelling the warning uploads nothing and keeps the tasks',
      (tester) async {
    await _insertPending(tester, ['a', 'b']);
    final controller = _RecordingController(dbHelper: dbHelper());

    await startLogout(tester, controller);
    await tapButton(tester, 'Cancel');

    expect(controller.logoutCalls, 0);
    expect(uploaded, isEmpty);
    expect(await tester.runAsync(controller.countPendingUploads), 2);
  });

  testWidgets('offline, confirming logs out without trying to upload',
      (tester) async {
    connectivity.current = [ConnectivityResult.none];
    await _insertPending(tester, ['a', 'b']);
    final controller = _RecordingController(dbHelper: dbHelper());

    await startLogout(tester, controller);
    await tapButton(tester, 'Logout anyway');

    expect(controller.logoutCalls, 1);
    expect(uploaded, isEmpty);
    expect(controller.pendingWhenLoggedOut, 2);
    expect(find.text('Some tasks were not saved'), findsNothing);
  });

  testWidgets('online, it uploads everything before logging out',
      (tester) async {
    await _insertPending(tester, ['a', 'b']);
    final controller = _RecordingController(dbHelper: dbHelper());

    await startLogout(tester, controller);
    await tapButton(tester, 'Logout anyway');

    expect(uploaded, unorderedEquals(['a', 'b']));
    expect(controller.logoutCalls, 1);
    expect(controller.pendingWhenLoggedOut, 0);
    expect(find.text('Some tasks were not saved'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  group('when some uploads still fail', () {
    testWidgets('the user can stay and keep the tasks', (tester) async {
      await _insertPending(tester, ['good', 'bad']);
      final controller =
          _RecordingController(dbHelper: dbHelper(failingKeys: {'bad'}));

      await startLogout(tester, controller);
      await tapButton(tester, 'Logout anyway');

      expect(find.text('Some tasks were not saved'), findsOneWidget);
      expect(find.text(failedLogoutMessage(1)), findsOneWidget);

      await tapButton(tester, 'Stay');

      expect(controller.logoutCalls, 0);
      expect(uploaded, ['good']);
      expect(controller.pendingCount.value, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the user can leave anyway and lose them', (tester) async {
      await _insertPending(tester, ['good', 'bad']);
      final controller =
          _RecordingController(dbHelper: dbHelper(failingKeys: {'bad'}));

      await startLogout(tester, controller);
      await tapButton(tester, 'Logout anyway');
      await tapButton(tester, 'Logout and lose it');

      expect(controller.logoutCalls, 1);
      expect(controller.pendingWhenLoggedOut, 1);
    });

    testWidgets(
        'an upload that never answers counts as failed after the timeout',
        (tester) async {
      await _insertPending(tester, ['stuck']);
      final controller = _RecordingController(
        dbHelper: dbHelper(stuckKeys: {'stuck'}),
        logoutSyncTimeout: const Duration(milliseconds: 100),
      );

      await startLogout(tester, controller);
      await tester.tap(find.widgetWithText(TextButton, 'Logout anyway'));
      await _settle(tester);
      expect(find.text('Saving your tasks...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      // Let the progress dialog finish its closing animation.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Saving your tasks...'), findsNothing);
      expect(find.text('Some tasks were not saved'), findsOneWidget);
      expect(controller.logoutCalls, 0);

      await tapButton(tester, 'Stay');
      expect(controller.logoutCalls, 0);
    });
  });
}
