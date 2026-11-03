import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/controller/add_task_controller.dart';
import 'package:to_do_app/view/new%20task/components/periority_container.dart';
import 'add_fild.dart';

class TitlePeriority extends StatelessWidget {
  final controller = Get.find<AddTaskController>();
  TitlePeriority({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Title',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(
          height: 10,
        ),
        Obx(
          () => AddInputField(
            controller: controller.title.value,
            focus: controller.titleFocus.value,
            onTap: () => controller.setTitleFocus(),
            onTapOutSide: () => controller.onTapOutside(),
            hint: 'Enter task title',
            width: double.infinity,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        const Text(
          'Priority',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Obx(
                () => PeriorityContainer(
                    onTap: () => controller.setPriority(Priority.high),
                    focus: controller.priority.value == Priority.high,
                    type: Priority.high.storedValue),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(
                () => PeriorityContainer(
                    onTap: () => controller.setPriority(Priority.medium),
                    focus: controller.priority.value == Priority.medium,
                    type: Priority.medium.storedValue),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(
                () => PeriorityContainer(
                    onTap: () => controller.setPriority(Priority.low),
                    focus: controller.priority.value == Priority.low,
                    type: Priority.low.storedValue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
