import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/menu_setup/data/preset_menus.dart';
import 'package:demo/features/menu_setup/services/menu_revision.dart';
import 'package:demo/Styles/my_font.dart';

Future<PresetMenu?> showPresetMenuPicker(BuildContext context) {
  return showDialog<PresetMenu>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Import Menu',
        style: TextStyle(fontFamily: fontMulishBold, fontSize: 18),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose a preset menu to import into this restaurant.',
              style: TextStyle(fontFamily: fontMulishRegular, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...kPresetMenus.map(
              (menu) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded),
                  title: Text(
                    menu.title,
                    style: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${menu.subtitle}\n'
                    '${menu.categoryCount} categories · ${menu.itemCount} items',
                    style: const TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 12,
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.of(ctx).pop(menu),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class MenuSeederPage extends StatefulWidget {
  const MenuSeederPage({super.key, this.presetMenuId});

  final String? presetMenuId;

  @override
  State<MenuSeederPage> createState() => _MenuSeederPageState();
}

class _MenuSeederPageState extends State<MenuSeederPage> {
  PresetMenu? _selectedMenu;
  bool _isRunning = false;
  bool _done = false;
  String _status = 'Press the button to start.';
  int _categoriesAdded = 0;
  int _itemsAdded = 0;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    if (widget.presetMenuId != null) {
      _selectedMenu = presetMenuById(widget.presetMenuId!);
    }
    if (_selectedMenu == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickMenuIfNeeded());
    }
  }

  Future<void> _pickMenuIfNeeded() async {
    if (!mounted || _selectedMenu != null || _isRunning) return;
    final menu = await showPresetMenuPicker(context);
    if (!mounted) return;
    if (menu == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _selectedMenu = menu);
  }

  void _log_(String msg) {
    setState(() {
      _log.add(msg);
      _status = msg;
    });
  }

  Map<String, dynamic> _itemPayload(
    Map<String, dynamic> item,
    int itemIndex,
  ) {
    final itemName = item['name'] as String;
    final payload = <String, dynamic>{
      'name': itemName,
      'sortOrder': itemIndex,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final includes = item['includes']?.toString().trim();
    if (includes != null && includes.isNotEmpty) {
      payload['includes'] = includes;
    }

    final rawVariants = item['variants'];
    if (rawVariants is List && rawVariants.isNotEmpty) {
      final variants = rawVariants
          .whereType<Map>()
          .map(
            (variant) => {
              'label': variant['label']?.toString() ?? '',
              'price': (variant['price'] as num).toDouble(),
              'name':
                  '$itemName (${variant['label']?.toString() ?? ''})',
            },
          )
          .where((variant) => (variant['label'] as String).isNotEmpty)
          .toList();
      if (variants.isNotEmpty) {
        payload['variants'] = variants;
        payload['price'] = (variants.first['price'] as num).toDouble();
        return payload;
      }
    }

    if (item.containsKey('halfPrice') && item.containsKey('fullPrice')) {
      payload['halfPrice'] = (item['halfPrice'] as num).toDouble();
      payload['fullPrice'] = (item['fullPrice'] as num).toDouble();
      payload['price'] = (item['halfPrice'] as num).toDouble();
      return payload;
    }

    payload['price'] = (item['price'] as num?)?.toDouble() ?? 0.0;
    return payload;
  }

  Future<void> _seedMenu() async {
    final menu = _selectedMenu;
    if (menu == null || _isRunning) return;

    setState(() {
      _isRunning = true;
      _done = false;
      _categoriesAdded = 0;
      _itemsAdded = 0;
      _log.clear();
      _status = 'Starting...';
    });

    try {
      _log_('Deleting existing menu...');
      final existing = await FirestorePaths.scoped('menus').get();
      for (final doc in existing.docs) {
        if (MenuRevision.isMetaDoc(doc.id)) continue;
        final items = await FirestorePaths
            .scopedSubCollection('menus', doc.id, 'items')
            .get();
        for (final item in items.docs) {
          await item.reference.delete();
        }
        await doc.reference.delete();
      }
      _log_('Cleared ${existing.docs.length} old categories.');

      final categories = menu.categories;
      for (var catIndex = 0; catIndex < categories.length; catIndex++) {
        final categoryData = categories[catIndex];
        final categoryName = categoryData['category'] as String;
        final items = (categoryData['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        _log_('[$catIndex] $categoryName');

        final catRef = await FirestorePaths.scoped('menus').add({
          'name': categoryName,
          'sortOrder': catIndex,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => _categoriesAdded++);

        for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = items[itemIndex];
          final payload = _itemPayload(item, itemIndex);

          await FirestorePaths
              .scopedSubCollection('menus', catRef.id, 'items')
              .add(payload);

          _log_('    • ${payload['name']}');
          setState(() => _itemsAdded++);
        }
      }

      await MenuRevision.bumpRevision();
      _log_(
        'Done! $_categoriesAdded categories, $_itemsAdded items imported from ${menu.title}.',
      );
      setState(() {
        _done = true;
        _isRunning = false;
      });
    } catch (e) {
      _log_('Error: $e');
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = _selectedMenu;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          menu == null ? 'Menu Seeder' : 'Import ${menu.title}',
          style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 16),
        ),
        actions: [
          if (!_isRunning)
            TextButton(
              onPressed: () async {
                final picked = await showPresetMenuPicker(context);
                if (picked != null && mounted) {
                  setState(() {
                    _selectedMenu = picked;
                    _done = false;
                    _log.clear();
                    _status = 'Press the button to start.';
                  });
                }
              },
              child: const Text('Change'),
            ),
        ],
      ),
      body: menu == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This will DELETE all existing menu data and import:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${menu.title}\n'
                          '• ${menu.categoryCount} categories\n'
                          '• ${menu.itemCount} menu items\n'
                          '• ${menu.subtitle}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isRunning || _done)
                    Row(
                      children: [
                        _Counter(
                          label: 'Categories',
                          value: _categoriesAdded,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        _Counter(
                          label: 'Items',
                          value: _itemsAdded,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  if (_isRunning || _done) const SizedBox(height: 16),
                  if (_isRunning)
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  if (_done)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _log.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _log[i],
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isRunning ? null : _seedMenu,
                      icon: Icon(_done ? Icons.refresh : Icons.upload_rounded),
                      label: Text(
                        _done
                            ? 'Re-Import ${menu.title}'
                            : _isRunning
                                ? 'Importing...'
                                : 'Delete Old Menu & Import ${menu.title}',
                        style: const TextStyle(
                          fontFamily: fontMulishSemiBold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _done ? Colors.orange : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Counter({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
