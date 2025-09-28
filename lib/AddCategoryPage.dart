import 'package:demo/AddMenuItemPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class AddCategoryPage extends StatefulWidget {
  @override
  _AddCategoryPageState createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _addCategory() async {
    if (_nameController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('menus').add({
      'name': _nameController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }).then((docRef) {
      _nameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Category added")),
      );
    });


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text("Add Category")),
            InkWell(
              onTap: () {
                Get.to(AddMenuItemPage());
              },
              child: Row(
                children: [
                  Icon(Icons.add_circle, size: 20),
                  SizedBox(width: 4),
                  Text("Menu"),
                ],
              ),
            )
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Category Input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Category Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addCategory,
              child: Text("Add Category"),
            ),
            SizedBox(height: 20),

            /// Category List (Real-time from Firestore)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('menus')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text("No categories found"));
                  }

                  final categories = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(category['name']),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              FirebaseFirestore.instance
                                  .collection('menus')
                                  .doc(category.id)
                                  .delete();
                            },
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


