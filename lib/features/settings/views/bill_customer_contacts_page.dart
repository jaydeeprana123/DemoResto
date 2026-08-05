import 'package:smartKitchen/features/settings/repositories/bill_customer_contacts_repository.dart';
import 'package:smartKitchen/features/ordering/widgets/whatsapp_share_phone_dialog.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class BillCustomerContactsPage extends StatelessWidget {
  const BillCustomerContactsPage({super.key});

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    final repo = Get.find<BillCustomerContactsRepository>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text(
          'WhatsApp Bill Customers',
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<List<BillCustomerContact>>(
        stream: repo.watchContacts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _orange));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load customers.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            );
          }

          final contacts = snapshot.data ?? [];
          if (contacts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No saved customers yet.\nThey appear here after you send a bill on WhatsApp from billing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final displayPhone = contact.mobile.isNotEmpty
                  ? WhatsAppSharePhoneDialog.formatForDisplay(contact.mobile)
                  : '+${contact.mobileNormalized}';
              final updated = contact.updatedAt != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(contact.updatedAt!)
                  : null;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: _orange.withValues(alpha: 0.12),
                    child: const Icon(Icons.person_outline, color: _orange),
                  ),
                  title: Text(
                    contact.name.isNotEmpty ? contact.name : 'Customer',
                    style: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 15,
                      color: _navy,
                    ),
                  ),
                  subtitle: Text(
                    [
                      displayPhone,
                      if (updated != null) 'Updated $updated',
                    ].join('\n'),
                    style: TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove customer?'),
                          content: Text(
                            'Remove ${contact.name.isNotEmpty ? contact.name : displayPhone} from saved list?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await repo.deleteContact(contact.id);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
