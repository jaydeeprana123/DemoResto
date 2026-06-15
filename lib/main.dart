import 'package:demo/core/network/app_http_overrides.dart';
import 'package:demo/bindings/app_binding.dart';
import 'package:demo/core/firebase/firebase_options.dart';
import 'package:demo/core/firestore/firestore_desktop_config.dart';
import 'package:demo/features/authentication/authentication.dart';
import 'package:demo/features/kitchen/services/kitchen_background_alert_service.dart';
import 'package:demo/features/kitchen/services/kitchen_settings.dart';
import 'package:demo/features/settings/services/print_settings.dart';
import 'package:demo/features/shell/services/app_tab_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppHttpOverrides.installIfNeeded();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await configureFirestoreForPlatform();
  await KitchenSettings.load();
  await KitchenBackgroundAlertService.initialize();
  await KitchenBackgroundAlertService.syncMonitoringEnabled(
    KitchenSettings.backgroundOrderRingtoneEnabled.value,
  );
  await AppTabSettings.load();
  await PrintSettings.load();

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return AuthGateView(key: ValueKey(snapshot.data!.uid));
          }
          return const LoginPage(key: ValueKey('login'));
        },
      ),
    );
  }
}
