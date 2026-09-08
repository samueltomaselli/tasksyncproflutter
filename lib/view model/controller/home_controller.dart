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
  RxBool focus = false.obs;
  RxBool hasText = false.obs;
  final searchQuery = ''.obs;

  List<int> get visibleTaskIndices {
    final query = searchQuery.value.trim().toLowerCase();
    return [
      for (var index = 0; index < list.length; index++)
        if (list[index].show == 'yes' &&
            (list[index].title ?? '').toLowerCase().contains(query))
          index,
    ];
  }
  RxInt taskCount = 0.obs;
  RxBool hasData = false.obs;
  final DbHelper db = DbHelper();
  RxList list = [].obs;
  Connectivity? connectivity;
  final searchController = TextEditingController().obs;
  @override
  void onInit() {
    super.onInit();
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
        int count = await FirebaseService.childCount();
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
        int count = await FirebaseService.childCount();

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
          var list = await db.getPendingUploads();
          for (int i = 0; i < list.length; i++) {
            try {
              await db.syncPendingUpload(list[i]);
            } catch (_) {
              // Keep the item pending so a later connectivity event can retry.
            }
          }
          list.clear();
          list = await db.getPendingDeletes();
          for (int i = 0; i < list.length; i++) {
            try {
              await db.syncPendingDelete(list[i]);
            } catch (_) {
              // Keep the deletion pending for a later retry.
            }
          }
          getTaskData();
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

  getTaskData() async {
    list.value = await db.getDataWithPending();
    checkData();
  }

  Future<List<TaskModel>> getFututeData() {
    return db.getData();
  }

  onClear(BuildContext context) {
    searchController.value.text = '';
    checkText();
    onTapOutside(context);
  }

  onTapOutside(BuildContext context) {
    focus.value = false;
    FocusScope.of(context).unfocus();
  }

  checkText() {
    hasText.value = searchController.value.text.toString().isNotEmpty;
    searchQuery.value = searchController.value.text;
  }

  onTapField() {
    focus.value = true;
  }

  getUserData() async {
    userData.value = await UserPref.getUser();
    getName();
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

  Future<void> logout() async {
    await FirebaseService.logout();
    await db.clearAllData();
    list.clear();
    userData.value = {};
    name.value = '';
    hasData.value = false;
    taskCount.value = 0;
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
