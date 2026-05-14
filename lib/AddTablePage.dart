import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Styles/my_font.dart';

// Same brand colours as login screen
const _navy   = Color(0xFF1A3A5C);
const _navyDk = Color(0xFF0D2137);
const _orange = Color(0xFFf57c35);
const _cardBg = Color(0xFF1E4570);

class AddTablePage extends StatefulWidget {
  @override
  _AddTablePageState createState() => _AddTablePageState();
}

class _AddTablePageState extends State<AddTablePage> {
  final _formKey = GlobalKey<FormState>();
  final _tableNameController = TextEditingController();

  Future<void> _addTable() async {
    if (_formKey.currentState!.validate()) {
      final name = _tableNameController.text.trim();

      await FirebaseFirestore.instance.collection('tables').add({
        'name': name,
        'createdAt': Timestamp.now(),
      });

      _tableNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Table '$name' added successfully"),
          backgroundColor: _orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteTable(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Table",
          style: TextStyle(color: _navy, fontFamily: fontMulishBold),
        ),
        content: Text(
          "Are you sure you want to delete '$name'?",
          style: TextStyle(color: Colors.black87, fontFamily: fontMulishRegular),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel",
                style: TextStyle(color: Colors.grey.shade600, fontFamily: fontMulishSemiBold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete",
                style: TextStyle(fontFamily: fontMulishSemiBold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('tables').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Table '$name' deleted"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _navy),
        title: Text(
          "Manage Tables",
          style: TextStyle(
            color: _navy,
            fontSize: 18,
            fontFamily: fontMulishBold,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Add Table Card ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add New Table",
                      style: TextStyle(
                        color: _navy,
                        fontSize: 15,
                        fontFamily: fontMulishBold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tableNameController,
                            style: const TextStyle(
                              color: _navy,
                              fontFamily: fontMulishSemiBold,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Table Name',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontFamily: fontMulishMedium,
                                fontSize: 13,
                              ),
                              hintText: 'e.g. Table 5',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.table_restaurant_outlined,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: _orange, width: 1.5),
                              ),
                              errorStyle: const TextStyle(color: Colors.redAccent),
                            ),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addTable,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            elevation: 2,
                            shadowColor: _orange.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: TextStyle(
                              fontFamily: fontMulishBold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Tables List Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "EXISTING TABLES",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontFamily: fontMulishBold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // ── Real-time List ────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tables')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _orange),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_restaurant_outlined,
                              color: Colors.grey.shade300, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            "No tables found",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontFamily: fontMulishSemiBold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final tables = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: tables.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final doc = tables[index];
                      final name = doc['name'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.table_restaurant_rounded,
                                color: _orange, size: 22),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: _navy,
                              fontSize: 15,
                              fontFamily: fontMulishBold,
                            ),
                          ),
                          subtitle: Text(
                            "Standard Table",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontFamily: fontMulishRegular,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.red.shade300, size: 24),
                            onPressed: () => _deleteTable(doc.id, name),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

