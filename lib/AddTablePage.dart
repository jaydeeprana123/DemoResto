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
          content: Text("Table '$name' added"),
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
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Table",
          style: TextStyle(color: Colors.white, fontFamily: fontMulishBold),
        ),
        content: Text(
          "Are you sure you want to delete '$name'?",
          style: TextStyle(color: Colors.white70, fontFamily: fontMulishRegular),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel",
                style: TextStyle(color: Colors.white60, fontFamily: fontMulishSemiBold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete",
                style: TextStyle(color: Colors.white, fontFamily: fontMulishSemiBold)),
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
      backgroundColor: _navyDk,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Manage Tables",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: fontMulishBold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_navy, _navyDk],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Add Table Card ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
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
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: fontMulishBold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tableNameController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: fontMulishSemiBold,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Table Name',
                                labelStyle: TextStyle(
                                  color: Colors.white60,
                                  fontFamily: fontMulishRegular,
                                  fontSize: 13,
                                ),
                                hintText: 'e.g. Table 1',
                                hintStyle: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.table_restaurant_outlined,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: _orange, width: 1.5),
                                ),
                                errorStyle: const TextStyle(color: Colors.orangeAccent),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Please enter a table name'
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
                                  horizontal: 20, vertical: 16),
                              elevation: 4,
                              shadowColor: _orange.withOpacity(0.4),
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

              const SizedBox(height: 20),

              // ── Tables List Header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  "Existing Tables",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: fontMulishSemiBold,
                    letterSpacing: 0.5,
                  ),
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
                                color: Colors.white24, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              "No tables yet",
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: fontMulishRegular,
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
                      itemBuilder: (context, index) {
                        final doc = tables[index];
                        final name = doc['name'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _orange.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.table_restaurant,
                                  color: _orange, size: 20),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: fontMulishSemiBold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 22),
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
      ),
    );
  }
}
