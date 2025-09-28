import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        SnackBar(content: Text("Table added")),
      );
    }
  }

  Future<void> _deleteTable(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Table"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('tables').doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Table deleted")),
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
      appBar: AppBar(
        title: Text("Add Table"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Form to add new table
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tableNameController,
                      decoration: InputDecoration(
                        labelText: 'Table Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Enter a name' : null,
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addTable,
                    child: Text('Add'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Real-time list of tables
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tables')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No tables found"));
                  }

                  final tables = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: tables.length,
                    itemBuilder: (context, index) {
                      final doc = tables[index];
                      final name = doc['name'] ?? '';

                      return ListTile(
                        title: Text(name),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTable(doc.id, name),
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



