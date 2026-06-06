import 'package:demo/bindings/app_binding.dart';
import 'package:demo/features/authentication/authentication.dart';
import 'package:demo/features/shell/shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCVEzgrDcjZOiv7R4QK3IH3kZBfq_Dh1Vo",
        authDomain: "resto-a0d9a.firebaseapp.com",
        projectId: "resto-a0d9a",
        storageBucket: "resto-a0d9a.firebasestorage.app",
        messagingSenderId: "799838711875",
        appId: "1:799838711875:web:0fae0ecb393db8cef624f6",
        measurementId: "G-ZPDSQ8MNJD",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flavor Flow',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(),
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const BottomNavigationView();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
