import 'dart:async';

import 'package:smartKitchen/core/network/app_http_overrides.dart';
import 'package:smartKitchen/bindings/app_binding.dart';
import 'package:smartKitchen/core/firebase/firebase_options.dart';
import 'package:smartKitchen/core/firestore/firestore_desktop_config.dart';
import 'package:smartKitchen/core/pwa/widgets/pwa_install_host.dart';
import 'package:smartKitchen/core/widgets/app_update_gate.dart';
import 'package:smartKitchen/features/authentication/authentication.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_background_alert_service.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_settings.dart';
import 'package:smartKitchen/features/settings/services/print_settings.dart';
import 'package:smartKitchen/features/shell/services/app_tab_settings.dart';
import 'package:smartKitchen/features/tables/services/dashboard_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:smartKitchen/features/kitchen/services/kitchen_web_bell_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppHttpOverrides.installIfNeeded();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await configureFirestoreForPlatform();
  await KitchenSettings.load();
  await DashboardSettings.load();
  await KitchenBackgroundAlertService.initialize();
  await AppTabSettings.load();
  await PrintSettings.load();
  if (kIsWeb) {
    unawaited(KitchenWebBellService.ensureInitialized());
    unawaited(KitchenBackgroundAlertService.initialize());
  }

  runApp(const MyApp());
}

Future<void> _syncKitchenMonitoring({bool promptIfNeeded = true}) {
  return KitchenBackgroundAlertService.syncMonitoringEnabled(
    KitchenSettings.backgroundOrderRingtoneEnabled.value ||
        DashboardSettings.orderCompletionNotificationEnabled.value,
    promptIfNeeded: promptIfNeeded,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncKitchenMonitoring());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncKitchenMonitoring(promptIfNeeded: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Smart Kitchen',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return AppUpdateGate(
          child: PwaInstallHost(child: content),
        );
      },
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
