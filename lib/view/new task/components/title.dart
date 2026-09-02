import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:to_do_app/view%20model/controller/add_task_controller.dart';
import 'package:to_do_app/view/new%20task/components/periority_container.dart';
import 'add_fild.dart';

class TitlePeriority extends StatelessWidget {
  final controller = Get.find<AddTaskController>();
  TitlePeriority({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Title',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
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
              )
            ],
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Periority',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Obx(
                      () => PeriorityContainer(
                          onTap: () => controller.setPeriority('High'),
                          focus: controller.periority.value == 'High',
                          type: "High"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(
                      () => PeriorityContainer(
                          onTap: () => controller.setPeriority('Medium'),
                          focus: controller.periority.value == 'Medium',
                          type: "Medium"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(
                      () => PeriorityContainer(
                          onTap: () => controller.setPeriority('Low'),
                          focus: controller.periority.value == 'Low',
                          type: "Low"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
}
