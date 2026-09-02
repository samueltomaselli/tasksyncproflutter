import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/utils/utils.dart';
import 'package:to_do_app/view%20model/DbHelper/db_helper.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';
import 'package:to_do_app/view/new%20task/components/progress_picker.dart';

class AddTaskController extends GetxController {
  AddTaskController({DbHelper? database, this.onRefresh})
      : database = database ?? DbHelper();

  final DbHelper database;
  final Future<void> Function()? onRefresh;
  TaskModel? editingTask;
  RxBool isEditing = false.obs;
  RxInt selectedImageIndex = 1.obs;
  RxString periority = 'High'.obs;
  RxBool titleFocus = false.obs;
  RxBool categoryFocus = false.obs;
  RxBool descriptionFocus = false.obs;
  RxBool loading = false.obs;
  RxDouble progress = 0.0.obs;
  Rx<TextEditingController> title = TextEditingController().obs;
  Rx<TextEditingController> description = TextEditingController().obs;
  Rx<TextEditingController> category = TextEditingController().obs;
  RxString time = ''.obs;
  RxString date = ''.obs;

  void startEditing(TaskModel task) {
    editingTask = task;
    isEditing.value = true;
    title.value.text = task.title ?? '';
    category.value.text = task.category ?? '';
    description.value.text = task.description ?? '';
    selectedImageIndex.value = _imageIndex(task.image);
    periority.value = task.periority ?? 'High';
    time.value = task.time ?? '';
    date.value = task.date ?? '';
    progress.value = double.tryParse(task.progress ?? '') ?? 0;
  }

  void resetForm() {
    editingTask = null;
    isEditing.value = false;
    title.value.clear();
    category.value.clear();
    description.value.clear();
    selectedImageIndex.value = 1;
    periority.value = 'High';
    time.value = '';
    date.value = '';
    progress.value = 0;
    loading.value = false;
    onTapOutside();
  }

  int _imageIndex(String? image) {
    final match =
        Utils.getImage().entries.where((entry) => entry.value == image);
    return match.isEmpty ? 1 : match.first.key;
  }

  Future<void> _refreshTasks() async {
    if (onRefresh != null) {
      await onRefresh!();
      return;
    }
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().getTaskData();
    }
  }

  Future<bool> saveTask() async {
    if (loading.value) return false;
    try {
      loading.value = true;
      final currentTask = editingTask;
      final task = TaskModel(
        key: currentTask?.key ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        time: time.value,
        date: date.value,
        periority: periority.value,
        description: description.value.text,
        category: category.value.text,
        title: title.value.text,
        image: Utils.getImage()[selectedImageIndex.value],
        show: currentTask?.show ?? 'yes',
        progress: progress.value.toInt().toString(),
        status: currentTask?.status ?? 'unComplete',
      );

      if (currentTask == null) {
        await database.insert(task);
      } else {
        await database.updateAndSync(task);
      }
      await _refreshTasks();
      return true;
    } catch (e) {
      Utils.showSnackBar(
        'Warning',
        e.toString(),
        Icon(
          FontAwesomeIcons.triangleExclamation.data,
          color: Colors.pinkAccent,
        ),
      );
      return false;
    } finally {
      loading.value = false;
    }
  }

  showProgressPicker(BuildContext context) {
    if (title.value.text.toString().isEmpty) {
      Utils.showSnackBar(
          'Warning',
          'Add title of your task',
          Icon(
            FontAwesomeIcons.triangleExclamation.data,
            color: Colors.pinkAccent,
          ));
      return;
    }
    if (category.value.text.toString().isEmpty) {
      Utils.showSnackBar(
          'Warning',
          'Add category of your task',
          Icon(
            FontAwesomeIcons.triangleExclamation.data,
            color: Colors.pinkAccent,
          ));
      return;
    }
    if (date.value.isEmpty) {
      Utils.showSnackBar(
          'Warning',
          'Add date for your task',
          Icon(
            FontAwesomeIcons.triangleExclamation.data,
            color: Colors.pinkAccent,
          ));
      return;
    }
    final isPastDate = int.parse(Utils.getDaysDiffirece(date.value)) < 0;
    final keptOriginalDate = isEditing.value && date.value == editingTask?.date;
    if (isPastDate && !keptOriginalDate) {
      Utils.showSnackBar(
          'Warning',
          'Please select correct date',
          Icon(
            FontAwesomeIcons.triangleExclamation.data,
            color: Colors.pinkAccent,
          ));
      return;
    }
    ProgressPicker(context);
  }

  pickDate(BuildContext context) async {
    final now = DateTime.now();
    var pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (pickedDate != null) {
      date.value = Utils.formateDate(pickedDate);
    }
  }

  picTime(BuildContext context) async {
    TimeOfDay? pickedTime =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime != null) {
      DateFormat dateFormat = DateFormat('hh:mm a');
      time.value = dateFormat.format(DateTime(
        2323,
        1,
        1,
        pickedTime.hour,
        pickedTime.minute,
      ));
    }
  }

  setTitleFocus() {
    titleFocus.value = true;
    categoryFocus.value = false;
    descriptionFocus.value = false;
  }

  setCategoryFocus() {
    titleFocus.value = false;
    categoryFocus.value = true;
    descriptionFocus.value = false;
  }

  setDescriptionFocus() {
    titleFocus.value = false;
    categoryFocus.value = false;
    descriptionFocus.value = true;
  }

  setPeriority(String value) {
    periority.value = value;
  }

  setImage(int index) {
    selectedImageIndex.value = index;
  }

  onTapOutside() {
    titleFocus.value = false;
    categoryFocus.value = false;
    descriptionFocus.value = false;
  }

  @override
  void onClose() {
    title.value.dispose();
    category.value.dispose();
    description.value.dispose();
    super.onClose();
  }
}
