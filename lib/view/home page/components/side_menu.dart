import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:to_do_app/utils/utils.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';

import '../../../res/app_color.dart';

class SideMenu extends StatelessWidget {
  SideMenu({super.key});
  final controller = Get.find<HomeController>();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: primaryColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Obx(
                () => Text(
                  'Hi, ${controller.name.value}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.pinkAccent),
              title: const Text('Sair', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                Utils.showWarningDailog(
                  Get.context!,
                  () => controller.logout(),
                  title: 'Sair',
                  message: 'Tem certeza que deseja sair da sua conta?',
                  confirmLabel: 'Sair',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
