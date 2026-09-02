import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';
import 'package:to_do_app/view%20model/controller/add_task_controller.dart';
import 'package:to_do_app/view/new%20task/new_task.dart';
import 'package:to_do_app/view/new%20task/components/addtask_body.dart';

class FakeDbHelper extends DbHelper {
  final List<TaskModel> insertedTasks = [];
  final List<TaskModel> localOnlyUpdates = [];
  final List<TaskModel> syncedUpdates = [];

  @override
  Future<TaskModel> insert(TaskModel model) async {
    insertedTasks.add(model);
    return model;
  }

  @override
  Future<void> update(TaskModel model) async {
    localOnlyUpdates.add(model);
  }

  @override
  Future<void> updateAndSync(TaskModel model) async {
    syncedUpdates.add(model);
  }
}

class BlockingDbHelper extends FakeDbHelper {
  final updateCompleter = Completer<void>();
  int updateCalls = 0;

  @override
  Future<void> updateAndSync(TaskModel model) async {
    updateCalls++;
    await updateCompleter.future;
    syncedUpdates.add(model);
  }
}

TaskModel existingTask() => TaskModel(
      key: 'task-123',
      title: 'Current title',
      category: 'Work',
      description: 'Current description',
      image: 'assets/images/back3.jpg',
      periority: 'High',
      time: '09:30 AM',
      date: '10 Sep 2026',
      show: 'yes',
      progress: '35',
      status: 'unComplete',
    );

TaskModel overdueTask() {
  final task = existingTask();
  task.date = DateFormat('d MMM y').format(
    DateTime.now().subtract(const Duration(days: 30)),
  );
  return task;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  test('startEditing prefills the task form with every current value', () {
    final database = FakeDbHelper();
    final controller = AddTaskController(
      database: database,
      onRefresh: () async {},
    );

    controller.startEditing(existingTask());

    expect(controller.isEditing.value, isTrue);
    expect(controller.title.value.text, 'Current title');
    expect(controller.category.value.text, 'Work');
    expect(controller.description.value.text, 'Current description');
    expect(controller.selectedImageIndex.value, 2);
    expect(controller.periority.value, 'High');
    expect(controller.time.value, '09:30 AM');
    expect(controller.date.value, '10 Sep 2026');
    expect(controller.progress.value, 35);
  });

  test('saveTask updates the existing task with the same key', () async {
    final database = FakeDbHelper();
    var refreshCount = 0;
    final controller = AddTaskController(
      database: database,
      onRefresh: () async => refreshCount++,
    );
    controller.startEditing(existingTask());
    controller.title.value.text = 'Updated title';
    controller.category.value.text = 'Personal';
    controller.description.value.text = 'Updated description';
    controller.selectedImageIndex.value = 3;
    controller.periority.value = 'Low';
    controller.time.value = '07:45 PM';
    controller.date.value = '12 Sep 2026';
    controller.progress.value = 80;

    final saved = await controller.saveTask();

    expect(saved, isTrue);
    expect(database.insertedTasks, isEmpty);
    expect(database.localOnlyUpdates, isEmpty);
    expect(database.syncedUpdates, hasLength(1));
    expect(database.syncedUpdates.single.toMap(), {
      'key': 'task-123',
      'title': 'Updated title',
      'category': 'Personal',
      'description': 'Updated description',
      'image': 'assets/images/back1.jpg',
      'periority': 'Low',
      'time': '07:45 PM',
      'date': '12 Sep 2026',
      'show': 'yes',
      'status': 'unComplete',
      'progress': '80',
    });
    expect(refreshCount, 1);
  });

  test('a new task defaults to High priority and can be set to Medium', () {
    final controller = AddTaskController(
      database: FakeDbHelper(),
      onRefresh: () async {},
    );

    expect(controller.periority.value, 'High');

    controller.setPeriority('Medium');
    expect(controller.periority.value, 'Medium');

    controller.setPeriority('Low');
    expect(controller.periority.value, 'Low');
  });

  test('editing a task and saving it with Medium priority persists Medium',
      () async {
    final database = FakeDbHelper();
    final controller = AddTaskController(
      database: database,
      onRefresh: () async {},
    );
    controller.startEditing(existingTask());
    expect(controller.periority.value, 'High');

    controller.setPeriority('Medium');
    final saved = await controller.saveTask();

    expect(saved, isTrue);
    expect(database.syncedUpdates.single.periority, 'Medium');
  });

  test('resetForm cancels editing without changing or saving the task', () {
    final database = FakeDbHelper();
    final task = existingTask();
    final controller = AddTaskController(
      database: database,
      onRefresh: () async {},
    );
    controller.startEditing(task);
    controller.title.value.text = 'Unsaved title';
    controller.progress.value = 99;

    controller.resetForm();

    expect(task.title, 'Current title');
    expect(task.progress, '35');
    expect(database.insertedTasks, isEmpty);
    expect(database.localOnlyUpdates, isEmpty);
    expect(database.syncedUpdates, isEmpty);
    expect(controller.isEditing.value, isFalse);
    expect(controller.editingTask, isNull);
    expect(controller.title.value.text, isEmpty);
    expect(controller.progress.value, 0);
  });

  test('saveTask ignores a second submission while saving', () async {
    final database = BlockingDbHelper();
    final controller = AddTaskController(
      database: database,
      onRefresh: () async {},
    );
    controller.startEditing(existingTask());

    final firstSave = controller.saveTask();
    await Future<void>.delayed(Duration.zero);
    final secondSave = controller.saveTask();
    await Future<void>.delayed(Duration.zero);
    database.updateCompleter.complete();

    expect(await secondSave, isFalse);
    expect(await firstSave, isTrue);
    expect(database.updateCalls, 1);
  });

  testWidgets('editing mode shows a prefilled update form', (tester) async {
    final controller = AddTaskController(
      database: FakeDbHelper(),
      onRefresh: () async {},
    );
    controller.startEditing(existingTask());
    Get.put<AddTaskController>(controller);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: TaskBody(controller: controller)),
      ),
    );

    expect(find.text('Update Task'), findsOneWidget);
    expect(find.text('Create Task'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Current title'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Work'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Current description'),
      findsOneWidget,
    );
  });

  testWidgets('dismissing the edit sheet discards the unsaved draft',
      (tester) async {
    final database = FakeDbHelper();
    final controller = AddTaskController(
      database: database,
      onRefresh: () async {},
    );
    Get.put<AddTaskController>(controller);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => NewTask(
                MediaQuery.sizeOf(context),
                task: existingTask(),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    expect(find.text('Update Task'), findsOneWidget);
    controller.title.value.text = 'Unsaved title';

    Get.back<void>();
    await tester.pumpAndSettle();

    expect(controller.isEditing.value, isFalse);
    expect(controller.title.value.text, isEmpty);
    expect(database.insertedTasks, isEmpty);
    expect(database.syncedUpdates, isEmpty);
  });

  testWidgets('confirming the edit saves once and closes the sheet',
      (tester) async {
    final database = FakeDbHelper();
    final controller = AddTaskController(
      database: database,
      onRefresh: () async {},
    );
    Get.put<AddTaskController>(controller);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => NewTask(
                MediaQuery.sizeOf(context),
                task: existingTask(),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    controller.title.value.text = 'Saved title';

    await tester.tap(find.text('Update Task'));
    await tester.pumpAndSettle();

    expect(find.text('Set Progress'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Update'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Update'));
    await tester.pumpAndSettle();

    expect(database.insertedTasks, isEmpty);
    expect(database.syncedUpdates, hasLength(1));
    expect(database.syncedUpdates.single.key, 'task-123');
    expect(database.syncedUpdates.single.title, 'Saved title');
    expect(find.text('Update Task'), findsNothing);
    expect(controller.isEditing.value, isFalse);
  });

  testWidgets('an overdue task can be edited without changing its date',
      (tester) async {
    final controller = AddTaskController(
      database: FakeDbHelper(),
      onRefresh: () async {},
    );
    controller.startEditing(overdueTask());
    Get.put<AddTaskController>(controller);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: TaskBody(controller: controller)),
      ),
    );

    await tester.tap(find.text('Update Task'));
    await tester.pumpAndSettle();

    expect(find.text('Set Progress'), findsOneWidget);
  });
}
