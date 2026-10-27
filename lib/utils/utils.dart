import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:to_do_app/res/app_color.dart';

class Utils {
  static bool validateEmail(String email) {
    return EmailValidator.validate(email);
  }

  static String extractFirebaseError(String error) {
    return error.substring(error.indexOf(']') + 1);
  }

  static void showSnackBar(
    String title,
    String message,
    Widget icon, {
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    Get.showSnackbar(GetSnackBar(
      backgroundColor: primaryColor.withOpacity(.4),
      title: title,
      isDismissible: true,
      duration: duration,
      icon: icon,
      message: message,
      snackPosition: SnackPosition.BOTTOM,
      borderRadius: 20,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      snackStyle: SnackStyle.GROUNDED,
      barBlur: 30,
    ));
  }

  static String unsyncedTasksMessage(int count) {
    final tasks = count == 1 ? '1 task is' : '$count tasks are';
    return '$tasks not saved to the cloud yet. '
        'We will try again when the connection is back.';
  }

  static void showSyncFailed(int count) {
    showSnackBar(
      'Not synced',
      unsyncedTasksMessage(count),
      const Icon(Icons.cloud_off, color: Colors.orangeAccent),
      duration: const Duration(seconds: 4),
    );
  }

  static String formateDate(DateTime date) {
    String formattedDate = DateFormat('d MMM y').format(date);
    return formattedDate;
  }

  static String formatDate() {
    String formattedDate = DateFormat('EEEE, d').format(DateTime.now());
    return formattedDate;
  }

  static Map<int, String> getImage() {
    return {
      1: 'assets/images/back2.jpg',
      2: 'assets/images/back3.jpg',
      3: 'assets/images/back1.jpg',
    };
  }

  static String getDaysDiffirece(String dateString) {
    DateFormat dateFormat = DateFormat('dd MMM yyyy');
    DateTime date = dateFormat.parse(dateString);
    DateTime now = DateTime.now();
    Duration difference = now.difference(date);
    return (-1 * difference.inDays).toString();
  }

  static Future<void> showWarningDailog(
    BuildContext context,
    VoidCallback onConfirm, {
    String title = 'Remove Task',
    String message = 'Are you sure you want to delete this Task?',
    String confirmLabel = 'Remove',
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(confirmLabel),
              onPressed: () {
                onConfirm();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Asks the user to confirm. Resolves to true only when they pick the
  /// confirm button; dismissing the dialog or cancelling resolves to false.
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text(cancelLabel),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              style: destructive
                  ? TextButton.styleFrom(foregroundColor: Colors.redAccent)
                  : null,
              child: Text(confirmLabel),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  /// Shows a blocking progress dialog while [task] runs, then closes it.
  static Future<T> runWithProgressDialog<T>(
    BuildContext context,
    String message,
    Future<T> Function() task,
  ) async {
    // Not awaited: the dialog future only completes when it is popped.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
