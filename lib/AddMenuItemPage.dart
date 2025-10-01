import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Styles/my_font.dart';

class AddMenuItemPage extends StatefulWidget {
  @override
  _AddMenuItemPageState createState() => _AddMenuItemPageState();
}

class _AddMenuItemPageState extends State<AddMenuItemPage> {
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _addMenuItem() async {
    if (_selectedCategoryId == null ||
        _nameController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('menus')
        .doc(_selectedCategoryId)
        .collection('items')
        .add({
          'name': _nameController.text.trim(),
          'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });

    _nameController.clear();
    _priceController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Menu item added to $_selectedCategoryName")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Menu Item", style: TextStyle(
      fontSize: 16,
      fontFamily: fontMulishSemiBold,
      ))),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown for categories
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('menus')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final categories = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: "Select Category"),
                  value: _selectedCategoryId,
                  items: categories.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedCategoryName = categories.firstWhere(
                        (doc) => doc.id == value,
                      )['name'];
                    });
                  },
                );
              },
            ),
            SizedBox(height: 20),

            // Menu Item Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Menu Item Name"),
            ),
            SizedBox(height: 10),

            // Price
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Price"),
            ),
            SizedBox(height: 20),

            // Add Button
            ElevatedButton(
              onPressed: _addMenuItem,
              child: Text("Add Menu Item"),
            ),
            SizedBox(height: 20),

            // Expanded list of categories + items
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('menus')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final categories = snapshot.data!.docs;

                  if (categories.isEmpty) {
                    return Center(child: Text("No categories found"));
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];

                      return ExpansionTile(
                        title: Text(
                          category['name'],
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('menus')
                                .doc(category.id)
                                .collection('items')
                                .orderBy('createdAt', descending: false)
                                .snapshots(),
                            builder: (context, itemSnapshot) {
                              if (!itemSnapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final items = itemSnapshot.data!.docs;

                              if (items.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text("No items in this category"),
                                );
                              }

                              return Container(
                                padding: EdgeInsets.only(left: 8),
                                child: Column(
                                  children: items.map((item) {
                                    return ListTile(
                                      title: Text(
                                        "${item['name']} - ₹${item['price']}",
                                        style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: fontMulishSemiBold,
                                      )
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          FirebaseFirestore.instance
                                              .collection('menus')
                                              .doc(category.id)
                                              .collection('items')
                                              .doc(item.id)
                                              .delete();
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ],
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
