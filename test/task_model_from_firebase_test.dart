import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/model/task_model.dart';

/// What `snapshot.value` returns for one task saved in the Realtime Database.
Map<Object?, Object?> firebaseTask() => {
      'key': 'task-42',
      'title': 'Comprar pão',
      'category': 'Casa',
      'description': 'Na padaria da esquina',
      'image': 'assets/images/back2.jpg',
      'periority': 'Medium',
      'time': '08:15 AM',
      'date': '03 Nov 2026',
      'show': 'yes',
      'progress': '60',
      'status': 'unComplete',
    };

void main() {
  test('a task read from Firebase keeps every field', () {
    final task = TaskModel.fromFirebase(firebaseTask());

    expect(task.key, 'task-42');
    expect(task.title, 'Comprar pão');
    expect(task.category, 'Casa');
    expect(task.description, 'Na padaria da esquina');
    expect(task.image, 'assets/images/back2.jpg');
    expect(task.priority, Priority.medium);
    expect(task.time, '08:15 AM');
    expect(task.date, '03 Nov 2026');
    expect(task.show, 'yes');
    expect(task.progress, '60');
    expect(task.status, 'unComplete');
  });

  test('numbers stored by Firebase become text, as the local table expects',
      () {
    final data = firebaseTask()..['progress'] = 60;

    expect(TaskModel.fromFirebase(data).progress, '60');
  });

  test('a missing field becomes the text "null", as the old conversion did',
      () {
    final data = firebaseTask()
      ..remove('description')
      ..remove('periority');
    final task = TaskModel.fromFirebase(data);

    expect(task.description, 'null');
    expect(task.priority, Priority.high);
  });

  test('a task read from Firebase saves the same map it was read from', () {
    final task = TaskModel.fromFirebase(firebaseTask());

    expect(task.toMap(), firebaseTask());
  });
}
