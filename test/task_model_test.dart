import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/model/task_model.dart';

TaskModel taskWithProgress(String progress) => TaskModel(
      key: 'task-123',
      title: 'Task',
      category: 'Work',
      description: '',
      image: 'assets/images/back2.jpg',
      priority: Priority.low,
      time: '',
      date: '10 Sep 2030',
      show: 'yes',
      progress: progress,
      status: 'unComplete',
    );

void main() {
  test('stored priorities keep their values and display Portuguese labels', () {
    const labels = {'High': 'Alta', 'Medium': 'Média', 'Low': 'Baixa'};
    for (final entry in labels.entries) {
      final task = TaskModel.fromMap({'periority': entry.key});
      expect(task.priorityLabel, entry.value);
      expect(task.toMap()['periority'], entry.key);
    }
  });

  test('missing and invalid stored priorities default to High', () {
    expect(TaskModel.fromMap({}).priorityLabel, 'Alta');
    for (final value in [null, '', 'null', 'Unknown', 42]) {
      final task = TaskModel.fromMap({'periority': value});
      expect(task.priorityLabel, 'Alta');
      expect(task.toMap()['periority'], 'High');
    }
  });

  test('progress values are exposed as a percentage and fraction', () {
    final task = taskWithProgress('35');

    expect(task.progressPercentage, 35);
    expect(task.progressFraction, 0.35);
  });

  test('progress is clamped to the valid indicator range', () {
    expect(taskWithProgress('150').progressPercentage, 100);
    expect(taskWithProgress('-20').progressPercentage, 0);
    expect(taskWithProgress('invalid').progressPercentage, 0);
  });
}
