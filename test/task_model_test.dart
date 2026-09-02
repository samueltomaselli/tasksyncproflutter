import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/model/task_model.dart';

TaskModel taskWithProgress(String progress) => TaskModel(
      key: 'task-123',
      title: 'Task',
      category: 'Work',
      description: '',
      image: 'assets/images/back2.jpg',
      periority: 'Low',
      time: '',
      date: '10 Sep 2030',
      show: 'yes',
      progress: progress,
      status: 'unComplete',
    );

void main() {
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
