import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/res/app_color.dart';
import 'package:to_do_app/view%20model/controller/add_task_controller.dart';
import 'package:to_do_app/view/new%20task/components/addtask_body.dart';

class NewTask {
  NewTask(Size size, {TaskModel? task}) {
    final controller = Get.isRegistered<AddTaskController>()
        ? Get.find<AddTaskController>()
        : Get.put(AddTaskController());
    if (task == null) {
      controller.resetForm();
    } else {
      controller.startEditing(task);
    }
    Get.bottomSheet(
            backgroundColor: black,
            isScrollControlled: true,
            TaskBody(controller: controller))
        .whenComplete(controller.resetForm);
  }
}
