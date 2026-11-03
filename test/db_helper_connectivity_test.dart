import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';

import 'helpers/memory_database.dart';

TaskModel pendingTask(String key) => TaskModel(
      key: key,
      title: 'Pending $key',
      category: 'Work',
      description: 'Description',
      image: 'assets/images/back2.jpg',
      periority: 'Low',
      time: '09:30 AM',
      date: '10 Sep 2030',
      show: 'yes',
      progress: '0',
      status: 'unComplete',
    );

DbHelper helperWith(List<ConnectivityResult> connection) => DbHelper(
      database: MemoryDatabase(),
      checkConnectivity: () async => connection,
      updateRemoteTask: (_) async {},
    );

void main() {
  group('isOnline', () {
    test('is true on Wi-Fi, mobile data and ethernet', () async {
      expect(await helperWith([ConnectivityResult.wifi]).isOnline(), isTrue);
      expect(await helperWith([ConnectivityResult.mobile]).isOnline(), isTrue);
      expect(
        await helperWith([ConnectivityResult.ethernet]).isOnline(),
        isTrue,
      );
    });

    test('is false without a network', () async {
      expect(await helperWith([ConnectivityResult.none]).isOnline(), isFalse);
      expect(
        await helperWith([ConnectivityResult.bluetooth]).isOnline(),
        isFalse,
      );
    });
  });

  group('syncPending', () {
    test('uploads queued tasks once the internet is back', () async {
      final database = MemoryDatabase();
      await database.insert('PendingUploads', pendingTask('a').toMap());
      await database.insert('PendingUploads', pendingTask('b').toMap());
      final uploaded = <String?>[];
      final helper = DbHelper(
        database: database,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        updateRemoteTask: (task) async => uploaded.add(task.key),
      );

      await helper.syncPending();

      expect(uploaded, unorderedEquals(['a', 'b']));
      expect(database.tables['PendingUploads'], isEmpty);
      expect(database.tables['Tasks']!.keys, unorderedEquals(['a', 'b']));
    });

    test('keeps a task queued when its upload fails again', () async {
      final database = MemoryDatabase();
      await database.insert('PendingUploads', pendingTask('a').toMap());
      final helper = DbHelper(
        database: database,
        checkConnectivity: () async => [ConnectivityResult.wifi],
        updateRemoteTask: (_) async => throw StateError('still offline'),
      );

      await helper.syncPending();

      expect(database.tables['PendingUploads']!.keys, ['a']);
      expect(database.tables['Tasks'], isEmpty);
    });

    test('does not call the server while offline', () async {
      final database = MemoryDatabase();
      await database.insert('PendingUploads', pendingTask('a').toMap());
      var remoteCalls = 0;
      final helper = DbHelper(
        database: database,
        checkConnectivity: () async => [ConnectivityResult.none],
        updateRemoteTask: (_) async => remoteCalls++,
      );

      await helper.syncPending();

      expect(remoteCalls, 0);
      expect(database.tables['PendingUploads']!.keys, ['a']);
    });
  });
}
