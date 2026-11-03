import 'dart:io';

/// Firebase (and google_sign_in) have no native Linux implementation, so
/// running `flutter run -d linux` crashes at startup. This flag switches
/// the app into a local-only mode on Linux so the native UI can still be
/// tested, backed by SharedPreferences/sqflite instead of Firebase.
/// `flutter test` also runs in this mode, so the suite gives the same result
/// on macOS and Windows as on the Linux CI.
final bool kUseFirebase =
    !Platform.isLinux && !Platform.environment.containsKey('FLUTTER_TEST');
