import 'package:flutter/material.dart';

/// Tells the user how many tasks exist only on this device. Renders nothing
/// when there is nothing waiting to be uploaded.
class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label =
        count == 1 ? '1 task waiting to sync' : '$count tasks waiting to sync';
    return Padding(
      key: const Key('pendingSyncBanner'),
      padding: const EdgeInsets.only(left: 30, right: 30, bottom: 30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: .5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
