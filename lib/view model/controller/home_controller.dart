import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:to_do_app/data/network/firebase/firebase_mode.dart';
import 'package:to_do_app/data/network/firebase/firebase_services.dart';
import 'package:to_do_app/data/shared%20pref/shared_pref.dart';
import 'package:to_do_app/utils/utils.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';
import 'package:to_do_app/view/new%20task/new_task.dart';
import '../../model/task_model.dart';
import '../../res/routes/routes.dart';

class HomeController extends GetxController {
  RxMap userData = {}.obs;
  RxString name = ''.obs;
  RxString email = ''.obs;
  RxString fullName = ''.obs;
  RxBool focus = false.obs;
  RxBool hasText = false.obs;
  RxInt taskCount = 0.obs;
  // Tasks saved only on this device, still waiting to be uploaded.
  RxInt pendingCount = 0.obs;
  RxBool hasData = false.obs;
  final DbHelper db;
  // Called with the number of tasks that could not be uploaded in a sync round.
  final void Function(int failed) onSyncFailed;
  // How long logout waits for pending uploads before giving up.
  final Duration logoutSyncTimeout;
  bool _syncingOnReconnect = false;
  RxList list = [].obs;
  Connectivity? connectivity;
  final searchController = TextEditingController().obs;
  HomeController({
    DbHelper? dbHelper,
    void Function(int failed)? syncFailedCallback,
    this.logoutSyncTimeout = const Duration(seconds: 10),
  })  : db = dbHelper ?? DbHelper(),
        onSyncFailed = syncFailedCallback ?? Utils.showSyncFailed {
    // if name not loaded
    if (userData['NAME'] == null) {
      getUserData();
    }
    // check for set listeners only for one time
    if (connectivity == null) {
      if (kUseFirebase) {
        String str = FirebaseService.auth.currentUser!.email.toString();
        String node = str.substring(0, str.indexOf('@'));
        // listener for changing live database
        FirebaseDatabase.instance
            .ref('Tasks')
            .child(node)
            .onValue
            .listen((event) async {
          // check if live database has more child than local

          getTaskData();
          for (var element in event.snapshot.children) {
            if (!await db.isRowExists(
                element.child('key').value.toString(), 'Tasks')) {
              db
                  .insert(
                TaskModel(
                    key: element.child('key').value.toString(),
                    time: element.child('time').value.toString(),
                    progress: element.child('progress').value.toString(),
                    status: element.child('status').value.toString(),
                    date: element.child('date').value.toString(),
                    periority: element.child('periority').value.toString(),
                    description: element.child('description').value.toString(),
                    category: element.child('category').value.toString(),
                    title: element.child('title').value.toString(),
                    image: element.child('image').value.toString(),
                    show: element.child('show').value.toString()),
              )
                  .then((value) {
                getTaskData();
              });
            }
          }
        });

        FirebaseDatabase.instance
            .ref('Tasks')
            .child(node)
            .onChildChanged
            .listen((event) async {
          // check if live database has more child than local
          getTaskData();
          for (var element in event.snapshot.children) {
            db
                .update(TaskModel(
                    progress: element.child('progress').value.toString(),
                    status: element.child('status').value.toString(),
                    key: element.child('key').value.toString(),
                    time: element.child('time').value.toString(),
                    date: element.child('date').value.toString(),
                    periority: element.child('periority').value.toString(),
                    description: element.child('description').value.toString(),
                    category: element.child('category').value.toString(),
                    title: element.child('title').value.toString(),
                    image: element.child('image').value.toString(),
                    show: element.child('show').value.toString()))
                .then((value) {
              getTaskData();
            });
          }
        });
      }
      connectivity = Connectivity();
      // listener for internet state
      connectivity!.onConnectivityChanged.listen((event) async {
        if (event.contains(ConnectivityResult.mobile) ||
            event.contains(ConnectivityResult.wifi)) {
          // Connectivity can flap; one round at a time, one message per round.
          if (_syncingOnReconnect) return;
          _syncingOnReconnect = true;
          try {
            final failed = await syncPendingUploads();
            final deletes = await db.getPendingDeletes();
            for (int i = 0; i < deletes.length; i++) {
              try {
                await db.syncPendingDelete(deletes[i]);
              } catch (e) {
                // Keep the deletion pending for a later retry.
                debugPrint('Could not delete task ${deletes[i].key}: $e');
              }
            }
            await getTaskData();
            if (failed > 0) onSyncFailed(failed);
          } finally {
            _syncingOnReconnect = false;
          }
        }
      });
    }
    getTaskData();
  }
  checkData() {
    int count = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i].show == 'yes') {
        count++;
      }
    }
    if (count > 0) {
      hasData.value = true;
      taskCount.value = count;
    } else {
      hasData.value = false;
      taskCount.value = 0;
    }
  }

  popupMenuSelected(int value, int index, BuildContext context) async {
    if (value == 1) {
      NewTask(MediaQuery.sizeOf(context), task: list[index]);
    } else if (value == 2) {
      Utils.showWarningDailog(context, () => removeFromList(index));
    }
  }

  /// Tries to upload every task in PendingUploads and returns how many could
  /// not be uploaded. Those stay pending so a later round can retry them.
  Future<int> syncPendingUploads() async {
    var failed = 0;
    for (final task in await db.getPendingUploads()) {
      try {
        await db.syncPendingUpload(task);
      } catch (e) {
        failed++;
        debugPrint('Could not upload task ${task.key}: $e');
      }
    }
    return failed;
  }

  Future<int> countPendingUploads() async {
    return (await db.getPendingUploads()).length;
  }

  Future<bool> isOnline() async {
    final connection = await Connectivity().checkConnectivity();
    return connection.contains(ConnectivityResult.wifi) ||
        connection.contains(ConnectivityResult.mobile) ||
        connection.contains(ConnectivityResult.ethernet);
  }

  /// Tries to upload every pending task before the session is cleared and
  /// returns how many are still pending. Firebase writes wait for the server
  /// instead of failing on a bad connection, so this gives up after
  /// [logoutSyncTimeout] and counts whatever did not finish as still pending.
  Future<int> syncBeforeLogout() async {
    try {
      await syncPendingUploads().timeout(logoutSyncTimeout);
    } on TimeoutException {
      debugPrint('Gave up uploading pending tasks after $logoutSyncTimeout');
    }
    await getTaskData();
    return pendingCount.value;
  }

  getTaskData() async {
    list.value = await db.getDataWithPending();
    pendingCount.value = (await db.getPendingUploads()).length;
    checkData();
  }

  Future<List<TaskModel>> getFututeData() {
    return db.getData();
  }

  onClear(BuildContext context) {
    searchController.value.text = '';
    hasText.value = false;
    onTapOutside(context);
  }

  onTapOutside(BuildContext context) {
    focus.value = false;
    FocusScope.of(context).unfocus();
  }

  checkText() {
    hasText.value = searchController.value.text.toString().isNotEmpty;
  }

  onTapField() {
    focus.value = true;
  }

  getUserData() async {
    userData.value = await UserPref.getUser();
    getName();
    getFullName();
    getEmail();
  }

  void getName() {
    final fullName = userData['NAME'].toString();
    final spaceIndex = fullName.indexOf(' ');

    if (spaceIndex != -1) {
      name.value = fullName.substring(0, spaceIndex);
    } else {
      name.value = fullName;
    }
  }

  void getFullName() {
    final name = userData['NAME'].toString();

    fullName.value = name;
  }

  void getEmail() {
    final fullEmail = userData['EMAIL'].toString();

    email.value = fullEmail;
  }

  Future<void> logout() async {
    await FirebaseService.logout();
    await db.clearAllData();
    list.clear();
    userData.value = {};
    name.value = '';
    hasData.value = false;
    taskCount.value = 0;
    pendingCount.value = 0;
    Get.offAllNamed(Routes.signInScreen);
  }

  removeFromList(int index) {
    db
        .removeFromList(TaskModel(
            key: list[index].key,
            status: list[index].status,
            progress: list[index].progress,
            time: list[index].time,
            date: list[index].date,
            periority: list[index].periority,
            description: list[index].description,
            category: list[index].category,
            title: list[index].title,
            image: list[index].image,
            show: 'no'))
        .then((value) {
      getTaskData();
    });
  }
}
