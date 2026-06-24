import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';

/// Firestore metadata used to detect menu changes without full reads.
class MenuRevision {
  MenuRevision._();

  static const metaDocId = '_meta';
  static const fieldRevision = 'menuRevision';
  static const prefsKeyPrefix = 'menu_revision_v1_';

  static bool isMetaDoc(String docId) => docId == metaDocId;

  static DocumentReference<Map<String, dynamic>> metaRef() {
    return FirestorePaths.scopedDoc('menus', metaDocId);
  }

  static int revisionFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return 0;
    final value = snapshot.data()?[fieldRevision];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static Future<int> readRemoteRevision() async {
    final snap = await metaRef().get();
    return revisionFromSnapshot(snap);
  }

  /// Increments menu revision. Pass [batch] to include in an existing write batch.
  static Future<void> bumpRevision({WriteBatch? batch}) async {
    final payload = <String, dynamic>{
      fieldRevision: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (batch != null) {
      batch.set(metaRef(), payload, SetOptions(merge: true));
      return;
    }

    await metaRef().set(payload, SetOptions(merge: true));
  }
}
