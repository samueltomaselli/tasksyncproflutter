import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';
import 'package:to_do_app/view/home%20page/home_page.dart';
import 'package:to_do_app/view/home%20page/components/progress_container.dart';

class SearchTestController extends HomeController {
  @override
  void onInit() {}
}

TaskModel task(String key, String title, {String show = 'yes'}) => TaskModel(
      key: key,
      title: title,
      category: 'Work',
      description: 'Description',
      image: 'assets/images/back3.jpg',
      periority: 'Low',
      time: '09:30 AM',
      date: '10 Sep 2030',
      show: show,
      progress: '35',
      status: 'unComplete',
    );

void main() {
  tearDown(Get.reset);

  Future<HomeController> openHome(WidgetTester tester) async {
    final controller = Get.put<HomeController>(SearchTestController());
    controller.list.assignAll([
      task('1', 'Buy groceries'),
      task('2', 'Write report'),
      task('3', 'Review report'),
      task('4', 'Hidden report', show: 'no'),
    ]);
    controller.checkData();
    await tester.pumpWidget(GetMaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(0.7)),
        child: child!,
      ),
      home: HomePage(),
    ));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
      'typing filters both lists by title and keeps original card indices',
      (tester) async {
    final controller = await openHome(tester);
    await tester.enterText(find.byType(TextFormField), '  REPORT  ');
    await tester.pumpAndSettle();
    expect(find.text('Create Buy groceries for\nWork'), findsNothing);
    expect(find.text('Create Write report for\nWork'), findsOneWidget);
    expect(find.text('Create Review report for\nWork'), findsOneWidget);
    expect(find.text('Create Hidden report for\nWork'), findsNothing);
    expect(
        tester
            .widgetList<ProgressContainer>(find.byType(ProgressContainer))
            .map((card) => card.index),
        [1, 2]);
    expect(controller.list.length, 4);
  });

  testWidgets('clearing by keyboard or X restores all visible tasks',
      (tester) async {
    await openHome(tester);
    for (final clearWithButton in [false, true]) {
      await tester.enterText(find.byType(TextFormField), 'report');
      await tester.pumpAndSettle();
      expect(find.text('Create Buy groceries for\nWork'), findsNothing);
      if (clearWithButton) {
        await tester.tap(find.byIcon(Icons.clear));
      } else {
        await tester.enterText(find.byType(TextFormField), '');
      }
      await tester.pumpAndSettle();
      expect(find.text('Create Buy groceries for\nWork'), findsOneWidget);
      expect(find.text('Create Write report for\nWork'), findsOneWidget);
      expect(find.text('Create Hidden report for\nWork'), findsNothing);
    }
  });

  testWidgets(
      'unmatched search is empty and remains active after a list refresh',
      (tester) async {
    final controller = await openHome(tester);
    await tester.enterText(find.byType(TextFormField), 'missing');
    await tester.pumpAndSettle();
    expect(find.byType(ProgressContainer), findsNothing);
    expect(find.textContaining('Create '), findsNothing);
    expect(tester.takeException(), isNull);
    controller.list
        .assignAll([task('5', 'Missing document'), task('6', 'Other')]);
    controller.checkData();
    await tester.pumpAndSettle();
    expect(find.text('Create Missing document for\nWork'), findsOneWidget);
    expect(find.text('Create Other for\nWork'), findsNothing);
  });
}
