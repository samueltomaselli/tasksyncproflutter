import 'dart:core';

enum Priority {
  high('High', 'Alta'),
  medium('Medium', 'Média'),
  low('Low', 'Baixa');

  const Priority(this.storedValue, this.label);

  final String storedValue;
  final String label;

  static Priority fromStorage(Object? value) {
    for (final priority in values) {
      if (priority.storedValue == value) return priority;
    }
    return high;
  }
}

class TaskModel {
  String? key;
  String? title;
  String? category;
  String? description;
  String? image;
  Priority priority;
  String? time;
  String? date;
  String? show;
  String? progress;
  String? status;

  TaskModel(
      {required this.key,
      required this.time,
      required this.date,
      required this.priority,
      required this.description,
      required this.category,
      required this.title,
      required this.image,
      required this.show,
      required this.progress,
      required this.status});

  int get progressPercentage {
    final value = double.tryParse(progress ?? '') ?? 0;
    return value.clamp(0, 100).round();
  }

  double get progressFraction => progressPercentage / 100;

  String get priorityLabel => priority.label;

  TaskModel.fromMap(Map<String, dynamic> res)
      : priority = Priority.fromStorage(res['periority']) {
    key = res['key'];
    title = res['title'];
    category = res['category'];
    description = res['description'];
    image = res['image'];
    show = res['show'];
    time = res['time'];
    date = res['date'];
    progress = res['progress'];
    status = res['status'];
  }

  /// Builds a task from what the Realtime Database returns for one task.
  /// Every field becomes text, so a missing field becomes "null".
  TaskModel.fromFirebase(Map data)
      : key = '${data['key']}',
        title = '${data['title']}',
        category = '${data['category']}',
        description = '${data['description']}',
        image = '${data['image']}',
        priority = Priority.fromStorage(data['periority']),
        time = '${data['time']}',
        date = '${data['date']}',
        show = '${data['show']}',
        progress = '${data['progress']}',
        status = '${data['status']}';

  Map<String, Object?> toMap() {
    return {
      'key': key,
      'title': title,
      'category': category,
      'description': description,
      'image': image,
      'periority': priority.storedValue,
      'time': time,
      'date': date,
      'show': show,
      'status': status,
      'progress': progress,
    };
  }
}
