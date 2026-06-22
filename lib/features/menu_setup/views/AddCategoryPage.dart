import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/menu_setup/services/menu_revision.dart';
import 'package:demo/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:demo/features/menu_setup/views/AddMenuItemPage.dart';
import 'package:demo/features/menu_setup/views/MenuSeederPage.dart';
import 'package:demo/features/menu_setup/widgets/setup_page_layout.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:demo/Styles/my_font.dart';

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isAdding = false;

  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    try {
      final name = _nameController.text.trim();
      final sortOrder = await nextSortOrder(FirestorePaths.scoped('menus'));
      await FirestorePaths.scoped('menus').add({
        'name': name,
        'sortOrder': sortOrder,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await MenuRevision.bumpRevision();
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "$name" added')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteCategory(String docId, String name) async {
    final confirmed = await SetupPageStyle.confirmDelete(
      context,
      title: 'Delete Category',
      message: "Are you sure you want to delete '$name'?",
    );
    if (confirmed != true || !mounted) return;

    await FirestorePaths.scopedDoc('menus', docId).delete();
    await MenuRevision.bumpRevision();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$name" deleted')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SetupPageLayout(
      appBarTitle: 'Menu Categories',
      wideTitle: 'Menu Categories',
      wideSubtitle: 'Create categories to organize your menu items',
      panelTitle: 'Menu\nCategories',
      panelSubtitle: 'Group your dishes into categories\n'
          'like Starters, Mains, and Beverages.',
      panelIllustration: SetupPageStyle.panelIllustration(
        centerIcon: Icons.menu_book_rounded,
        rightIcon: Icons.category_outlined,
      ),
      appBarActions: [
        TextButton.icon(
          onPressed: () => Get.to(() => const MenuSeederPage()),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text(
            'Import',
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(foregroundColor: SetupPageColors.green),
        ),
        TextButton.icon(
          onPressed: () => Get.to(() => const AddMenuItemPage()),
          icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
          label: const Text(
            'Items',
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SetupPageStyle.label('Category Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _addCategory(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a category name'
                      : null,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: fontMulishRegular,
                    color: SetupPageColors.navy,
                  ),
                  decoration: SetupPageStyle.inputDecoration(
                    hint: 'e.g. Starters, Main Course, Drinks',
                    icon: Icons.category_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                _isAdding
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SetupPageColors.orange,
                        ),
                      )
                    : SetupPageStyle.primaryButton(
                        label: 'Add Category',
                        icon: Icons.add_rounded,
                        onTap: _addCategory,
                      ),
              ],
            ),
          ),
          SetupPageStyle.sectionDivider('your categories'),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestorePaths.scoped('menus').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: SetupPageColors.orange),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SetupPageStyle.emptyState(
            icon: Icons.category_outlined,
            title: 'No categories found',
            subtitle: 'Add your first category above',
          );
        }

        final categories = sortMenuDocs(
          snapshot.data!.docs
              .where((doc) => !MenuRevision.isMetaDoc(doc.id))
              .toList(),
        );

        return ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final category = categories[index];
            final name = category.data()['name']?.toString() ?? '';

            return SetupPageStyle.listCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: SetupPageStyle.leadingIcon(
                  icon: Icons.folder_outlined,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 15,
                    color: SetupPageColors.navy,
                  ),
                ),
                subtitle: Text(
                  'Tap Items in app bar to add menu items',
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  tooltip: 'Delete category',
                  onPressed: () => _deleteCategory(category.id, name),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
