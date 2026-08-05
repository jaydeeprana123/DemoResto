import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/features/ordering/widgets/whatsapp_share_phone_dialog.dart';

class BillCustomerContact {
  const BillCustomerContact({
    required this.id,
    required this.name,
    required this.mobile,
    required this.mobileNormalized,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String mobile;
  final String mobileNormalized;
  final DateTime? updatedAt;

  factory BillCustomerContact.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final updated = data['updatedAt'];
    return BillCustomerContact(
      id: doc.id,
      name: data['name']?.toString().trim() ?? '',
      mobile: data['mobile']?.toString().trim() ?? '',
      mobileNormalized: data['mobileNormalized']?.toString() ?? doc.id,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}

class BillCustomerContactsRepository {
  Stream<List<BillCustomerContact>> watchContacts() {
    return FirestorePaths
        .scoped('bill_customer_contacts')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(BillCustomerContact.fromDoc).toList(),
        );
  }

  /// Saves or updates a WhatsApp bill customer keyed by normalized mobile.
  Future<void> upsertContact({
    required String name,
    required String mobile,
  }) async {
    final trimmedName = name.trim();
    final trimmedMobile = mobile.trim();
    if (trimmedMobile.isEmpty) return;

    final normalized = WhatsAppSharePhoneDialog.normalizePhone(trimmedMobile);
    if (normalized.isEmpty) return;

    await FirestorePaths.scopedDoc('bill_customer_contacts', normalized).set(
      {
        'name': trimmedName,
        'mobile': trimmedMobile,
        'mobileNormalized': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteContact(String id) async {
    await FirestorePaths.scopedDoc('bill_customer_contacts', id).delete();
  }
}
