import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:to_do_app/data/network/firebase/firebase_mode.dart';
import 'package:to_do_app/res/routes/app_routes.dart';
void main()async{
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    // sqflite has no native Linux implementation either; use the ffi backend.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  if (kUseFirebase) {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      getPages: AppRoutes.routes(),
    );
  }
}

