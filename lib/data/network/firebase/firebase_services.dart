import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:to_do_app/data/shared%20pref/shared_pref.dart';
import 'package:to_do_app/model/task_model.dart';
import 'package:to_do_app/utils/utils.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:to_do_app/view%20model/controller/signin_controller.dart';
import 'package:to_do_app/view/home%20page/home_page.dart';
import '../../../view model/controller/signup_controller.dart';
import 'firebase_mode.dart';


class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseDatabase get database => FirebaseDatabase.instance;
  static final signInController = Get.put(SignInController());
  static final signUpController = Get.put(SignupController());



  static Future<void> insertData(TaskModel model)async{
    if (!kUseFirebase) return;
     String str = auth.currentUser!.email.toString();
     String node = str.substring(0, str.indexOf('@'));
    database.ref('Tasks').child(node).child(model.key!).set({
      'key' : model.key,
      'title' : model.title,
      'description' : model.description,
      'category' : model.category,
      'date' : model.date,
      'time' : model.time,
      'image' : model.image,
      'periority' : model.periority,
      'show' : model.show,
    }).then((value) {

    }).onError((error, stackTrace){

    });
  }
  static bool _isPigeonCast(Object e) {
    final msg = e.toString();
    return msg.contains('PigeonUserDetails') || msg.contains('PigeonUserInfo');
  }

  static Icon get _errorIcon => Icon(
        FontAwesomeIcons.triangleExclamation.data,
        color: Colors.red,
      );

  static Future<User> _authUser(Future<UserCredential> fn) async {
    try {
      final cred = await fn;
      return cred.user ?? auth.currentUser!;
    } catch (e) {
      final user = auth.currentUser;
      if (_isPigeonCast(e) && user != null) return user;
      rethrow;
    }
  }

  static Future<void> createAccount() async {
    try {
      signUpController.setLoading(true);
      final email = signUpController.email.value.text.toString();
      final password = signUpController.password.value.text.toString();
      final name = '${signUpController.name.value.text}';
      final node = email.substring(0, email.indexOf('@'));
      if (!kUseFirebase) {
        await UserPref.setUser(name, email, password, node, 'local-$node');
        Utils.showSnackBar(
          'Sign up',
          'Linux test mode: account simulated locally (no Firebase)',
          const Icon(Icons.done, color: Colors.white),
        );
        Get.to(HomePage());
        return;
      }
      await database.ref('Accounts').child(node).set({
        'name': name,
        'email': email,
        'password': password,
      });
      final user = await _authUser(auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ));
      await UserPref.setUser(name, email, password, node, user.uid);
      Utils.showSnackBar(
        'Sign up',
        "Account is successfully created",
        const Icon(Icons.done, color: Colors.white),
      );
      Get.to(HomePage());
    } catch (e) {
      Utils.showSnackBar('Error', Utils.extractFirebaseError(e.toString()), _errorIcon);
    } finally {
      signUpController.setLoading(false);
    }
  }

  static Future<void> loginAccount() async {
    try {
      signInController.setLoading(true);
      if (!kUseFirebase) {
        const node = 'linuxtester';
        await UserPref.setUser(
          'Linux Tester',
          'tester@local',
          'local',
          node,
          'local-$node',
        );
        Utils.showSnackBar(
          'Login',
          'Linux test mode: login simulated locally (no Firebase)',
          const Icon(Icons.done, color: Colors.white),
        );
        Get.to(HomePage());
        return;
      }
      final user = await _authUser(auth.signInWithEmailAndPassword(
        email: signInController.email.value.text.toString(),
        password: signInController.password.value.text.toString(),
      ));
      final node = user.email!.substring(0, user.email!.indexOf('@'));
      final snap = await database.ref('Accounts').child(node).get();
      await UserPref.setUser(
        snap.child('name').value.toString(),
        snap.child('email').value.toString(),
        snap.child('password').value.toString(),
        node,
        user.uid,
      );
      Utils.showSnackBar(
        'Login',
        "Successfully Login.Welcome Back!",
        const Icon(Icons.done, color: Colors.white),
      );
      Get.to(HomePage());
    } catch (e) {
      Utils.showSnackBar('Error', Utils.extractFirebaseError(e.toString()), _errorIcon);
    } finally {
      signInController.setLoading(false);
    }
  }

  static Future<void> signInwWithGoogle() async {
    if (!kUseFirebase) {
      Utils.showSnackBar(
        'Unavailable',
        'Google sign-in is disabled in Linux test mode',
        _errorIcon,
      );
      return;
    }
    try {
      final googleSignIn = GoogleSignIn();
      GoogleSignInAccount? googleAccount;
      try {
        googleAccount = await googleSignIn.signIn();
      } catch (e) {
        if (!_isPigeonCast(e)) rethrow;
        googleAccount = await googleSignIn.signInSilently();
      }
      if (googleAccount == null) return;
      final googleAuth = await googleAccount.authentication;
      final user = await _authUser(auth.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        ),
      ));
      final email = user.email.toString();
      final node = email.substring(0, email.indexOf('@'));
      await database.ref('Accounts').child(node).set({
        'name': user.displayName,
        'email': user.email,
      });
      await UserPref.setUser(
        user.displayName ?? '',
        email,
        "NOPASSWORD",
        node,
        user.uid,
      );
      Utils.showSnackBar(
        'Login',
        'Successfully Login',
        const Icon(Icons.done, color: Colors.white),
      );
      Get.to(HomePage());
    } catch (e) {
      Utils.showSnackBar('Error', Utils.extractFirebaseError(e.toString()), _errorIcon);
    }
  }
  static Future<void> signInWithApple()async{
  }
  static Future<int> childCount()async{
    if (!kUseFirebase) return 0;
    String str = auth.currentUser!.email.toString();
    String node = str.substring(0, str.indexOf('@'));
    return database.ref('Tasks').child(node).once().then((value){
      return value.snapshot.children.length;
    });
  }
  static Future<void> update(String key,String updateKey,String updateValue) async{
    if (!kUseFirebase) return;
    String str = auth.currentUser!.email.toString();
    String node = str.substring(0, str.indexOf('@'));
   database.ref('Tasks').child(node).child(key).update({
     updateKey : updateValue
   });
  }


}
