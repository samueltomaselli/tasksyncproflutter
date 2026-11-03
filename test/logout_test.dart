// Covers the new "Logout" (logout) feature end to end:
// - UserPref.clearUser wipes the saved session.
// - DbHelper.clearAllData wipes locally cached tasks (so a previous
//   account's data isn't visible on a shared device).
// - FirebaseService.logout clears the local session (kUseFirebase is
//   false on this test host, so the real Firebase Auth call is skipped,
//   matching how the app behaves in Linux test mode).
// - Tapping the hamburger icon opens the side menu, tapping "Logout" and
//   confirming clears the session and lands on the sign-in screen.
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_app/data/network/firebase/firebase_services.dart';
import 'package:to_do_app/data/shared%20pref/shared_pref.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/res/routes/app_routes.dart';
import 'package:to_do_app/res/routes/routes.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';
import 'package:to_do_app/view/sign%20in/sign_in.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getExternalStoragePath() async => path;
  @override
  Future<String?> getDownloadsPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
}

class _OfflineConnectivityPlatform extends ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.none];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

TaskModel _sampleTask() => TaskModel(
      key: 'task-logout-1',
      title: 'Sample task',
      category: 'Work',
      description: 'Sample description',
      image: 'assets/images/back1.jpg',
      periority: 'High',
      time: '09:00 AM',
      date: '10 Sep 2026',
      show: 'yes',
      progress: '10',
      status: 'unComplete',
    );

void _seedLoggedInSession() {
  SharedPreferences.setMockInitialValues({
    'NAME': 'Test User',
    'EMAIL': 'test@example.com',
    'PASSWORD': 'secret',
    'NODE': 'test',
    'TOKEN': 'token-abc',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('logout_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    ConnectivityPlatform.instance = _OfflineConnectivityPlatform();
    _seedLoggedInSession();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('UserPref.clearUser removes every saved session key', () async {
    final before = await SharedPreferences.getInstance();
    expect(before.getString('TOKEN'), 'token-abc');

    await UserPref.clearUser();

    final after = await SharedPreferences.getInstance();
    expect(after.getString('TOKEN'), isNull);
    expect(after.getString('NAME'), isNull);
    expect(after.getString('EMAIL'), isNull);
  });

  test('DbHelper.clearAllData wipes Tasks, PendingUploads and PendingDeletes',
      () async {
    final helper = DbHelper();
    final rawDb = await helper.db;
    final task = _sampleTask().toMap();
    await rawDb!.insert('Tasks', task);
    await rawDb.insert('PendingUploads', {...task, 'key': 'task-logout-2'});
    await rawDb.insert('PendingDeletes', {...task, 'key': 'task-logout-3'});

    expect(await helper.getData(), isNotEmpty);
    expect(await helper.getPendingUploads(), isNotEmpty);
    expect(await helper.getPendingDeletes(), isNotEmpty);

    await helper.clearAllData();

    expect(await helper.getData(), isEmpty);
    expect(await helper.getPendingUploads(), isEmpty);
    expect(await helper.getPendingDeletes(), isEmpty);
  });

  test(
      'FirebaseService.logout clears the local session without touching Firebase in Linux test mode',
      () async {
    await FirebaseService.logout();

    final pref = await SharedPreferences.getInstance();
    expect(pref.getString('TOKEN'), isNull);
  });

  testWidgets(
      'tapping the menu icon, then Logout, then confirming logs out and returns to sign-in',
      (tester) async {
    // testWidgets runs on a fake clock, so the real sqflite/ffi I/O below
    // only completes inside tester.runAsync.
    final helper = DbHelper();
    await tester.runAsync(() async {
      final rawDb = await helper.db;
      await rawDb!.insert('Tasks', _sampleTask().toMap());
    });

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The test font (Ahem) is much wider than the real one, so the home
    // screen reports RenderFlex overflows that don't happen on a device.
    // They are unrelated to logout, so ignore only that kind of error.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('A RenderFlex overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(GetMaterialApp(
      initialRoute: Routes.homePage,
      getPages: AppRoutes.routes(),
    ));
    await _settle(tester);

    final controller = Get.find<HomeController>();
    expect(controller.list, isNotEmpty);

    await tester.tap(find.byKey(const Key('menuButton')));
    await _settle(tester);
    expect(find.text('Logout'), findsWidgets);

    await tester.tap(find.text('Logout').first);
    await _settle(tester);
    expect(find.widgetWithText(TextButton, 'Logout'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Logout'));
    await _settle(tester);

    expect(controller.list, isEmpty);
    await tester.runAsync(() async {
      final pref = await SharedPreferences.getInstance();
      expect(pref.getString('TOKEN'), isNull);
      expect(await helper.getData(), isEmpty);
    });
    expect(find.byType(SignIn), findsOneWidget);
  });
}

/// Lets real async work (database, shared prefs) finish, then pumps the
/// frames it triggered. Work started while building widgets continues on the
/// fake clock, so each step needs real time *and* a pump to advance.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
