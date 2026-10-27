import 'package:flutter/material.dart';
import 'package:to_do_app/utils/utils.dart';
import 'package:to_do_app/view%20model/controller/home_controller.dart';

String unsyncedLogoutMessage(int count) {
  final tasks = count == 1 ? '1 task is' : '$count tasks are';
  final they = count == 1 ? 'it' : 'they';
  return '$tasks not saved to the cloud yet. '
      'If you log out now, $they will be lost.';
}

String failedLogoutMessage(int count) {
  final tasks = count == 1 ? '1 task' : '$count tasks';
  final them = count == 1 ? 'it' : 'them';
  return '$tasks could not be uploaded. Log out and lose $them?';
}

/// What happens when the user taps "Logout".
/// - Nothing pending: a plain confirmation.
/// - Pending tasks: warn how many will be lost; if the user goes ahead and
///   there is internet, upload them first (before the session is cleared),
///   and ask once more if some still could not be uploaded. The user can
///   always leave in the end, so a broken connection never traps them.
Future<void> confirmAndLogout(
    BuildContext context, HomeController controller) async {
  final pending = await controller.countPendingUploads();
  if (!context.mounted) return;

  if (pending == 0) {
    final confirmed = await Utils.showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
    );
    if (confirmed) await controller.logout();
    return;
  }

  final goAhead = await Utils.showConfirmDialog(
    context,
    title: 'Unsynced tasks',
    message: unsyncedLogoutMessage(pending),
    confirmLabel: 'Logout anyway',
    destructive: true,
  );
  if (!goAhead || !context.mounted) return;

  if (await controller.isOnline()) {
    if (!context.mounted) return;
    final remaining = await Utils.runWithProgressDialog(
      context,
      'Saving your tasks...',
      controller.syncBeforeLogout,
    );
    if (remaining > 0) {
      if (!context.mounted) return;
      final loseThem = await Utils.showConfirmDialog(
        context,
        title: 'Some tasks were not saved',
        message: failedLogoutMessage(remaining),
        cancelLabel: 'Stay',
        confirmLabel:
            remaining == 1 ? 'Logout and lose it' : 'Logout and lose them',
        destructive: true,
      );
      if (!loseThem) return;
    }
  }
  await controller.logout();
}
