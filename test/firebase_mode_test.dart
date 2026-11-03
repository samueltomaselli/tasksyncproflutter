import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_app/data/network/firebase/firebase_mode.dart';

void main() {
  test('tests run without Firebase on every operating system', () {
    expect(kUseFirebase, isFalse);
  });
}
