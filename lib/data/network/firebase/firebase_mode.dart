import 'dart:io';

/// Firebase (and google_sign_in) have no native Linux implementation, so
/// running `flutter run -d linux` crashes at startup. This flag switches
/// the app into a local-only mode on Linux so the native UI can still be
/// tested, backed by SharedPreferences/sqflite instead of Firebase.
final bool kUseFirebase = !Platform.isLinux;
