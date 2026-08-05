import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/utils/platform_utils.dart';

/// Desktop Firestore tuning to reduce Windows C++ SDK threading crashes.
Future<void> configureFirestoreForPlatform() async {
  if (!isDesktopPlatform) return;

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
}
