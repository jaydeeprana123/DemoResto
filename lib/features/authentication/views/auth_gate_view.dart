import 'package:smartKitchen/core/services/restaurant_session.dart';
import 'package:smartKitchen/features/authentication/services/device_session_service.dart';
import 'package:smartKitchen/features/authentication/views/blocked_access_view.dart';
import 'package:smartKitchen/features/shell/shell.dart';
import 'package:smartKitchen/features/super_admin/super_admin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthGateView extends StatefulWidget {
  const AuthGateView({super.key});

  @override
  State<AuthGateView> createState() => _AuthGateViewState();
}

class _AuthGateViewState extends State<AuthGateView> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadSession();
  }

  Future<void> _loadSession() async {
    final session = Get.find<RestaurantSession>();
    await session.loadForCurrentUser();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && Get.isRegistered<DeviceSessionService>()) {
      await Get.find<DeviceSessionService>().startWatching(user.uid);
    }
  }

  void _showExpiryWarning(RestaurantAccessInfo access) {
    if (!access.showExpiryWarning || access.message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(access.message!),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = Get.find<RestaurantSession>();

        if (session.profile.value == null) {
          return const BlockedAccessView(
            message:
                'Your account is not set up. Contact Super Admin or Restaurant Admin.',
          );
        }

        if (session.isSuperAdmin) {
          SuperAdminBinding().dependencies();
          return const SuperAdminHomeView();
        }

        final access = session.evaluateAccess();
        if (!access.allowed) {
          return BlockedAccessView(
            message: access.message ?? 'Access denied.',
            restaurantName: access.restaurant?.name,
          );
        }

        _showExpiryWarning(access);
        return const BottomNavigationView();
      },
    );
  }
}
