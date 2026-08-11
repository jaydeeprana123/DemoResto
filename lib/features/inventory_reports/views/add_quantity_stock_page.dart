import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/inventory_reports/repositories/inventory_reports_repository.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_date_utils.dart';
import 'package:smartKitchen/features/inventory_reports/widgets/inventory_report_widgets.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AddQuantityStockPage extends StatefulWidget {
  const AddQuantityStockPage({super.key});

  @override
  State<AddQuantityStockPage> createState() => _AddQuantityStockPageState();
}

class _AddQuantityStockPageState extends State<AddQuantityStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');
  final _priceController = TextEditingController();
  final _minStockController = TextEditingController();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _itemSearchController = TextEditingController();

  List<InventoryCatalogItem> _catalog = [];
  InventoryCatalogItem? _selected;
  DateTime _stockDate = DateTime.now();
  bool _loadingCatalog = true;
  bool _saving = false;
  String _itemQuery = '';

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _minStockController.dispose();
    _supplierController.dispose();
    _invoiceController.dispose();
    _reasonController.dispose();
    _itemSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    try {
      final catalog =
          await Get.find<InventoryReportsRepository>().loadCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
      Get.snackbar(
        'Error',
        'Could not load menu items: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }

  List<InventoryCatalogItem> get _filteredCatalog {
    final q = _itemQuery.trim().toLowerCase();
    if (q.isEmpty) return _catalog;
    return _catalog
        .where(
          (item) =>
              item.name.toLowerCase().contains(q) ||
              item.categoryName.toLowerCase().contains(q),
        )
        .toList();
  }

  void _selectItem(InventoryCatalogItem item) {
    setState(() {
      _selected = item;
      _unitController.text = item.unit.isNotEmpty ? item.unit : 'pcs';
      if (item.costPerUnit > 0) {
        _priceController.text = item.costPerUnit == item.costPerUnit.roundToDouble()
            ? item.costPerUnit.toInt().toString()
            : item.costPerUnit.toStringAsFixed(2);
      }
      if (item.minimumStock > 0) {
        _minStockController.text =
            item.minimumStock == item.minimumStock.roundToDouble()
                ? item.minimumStock.toInt().toString()
                : item.minimumStock.toStringAsFixed(2);
      }
      _itemQuery = '';
      _itemSearchController.clear();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _stockDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _stockDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _selected;
    if (item == null) {
      Get.snackbar(
        'Item required',
        'Please select a menu item.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) return;

    final purchasePrice = double.tryParse(_priceController.text.trim());
    final minStock = double.tryParse(_minStockController.text.trim());

    setState(() => _saving = true);
    try {
      final newStock = await Get.find<InventoryReportsRepository>().addStockIn(
        item: item,
        quantity: qty,
        stockDate: _stockDate,
        unit: _unitController.text.trim().isEmpty
            ? 'pcs'
            : _unitController.text.trim(),
        purchasePrice: purchasePrice,
        costPerUnit: purchasePrice,
        minimumStock: minStock,
        supplier: _supplierController.text.trim(),
        invoiceNumber: _invoiceController.text.trim(),
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;
      Get.snackbar(
        'Stock added',
        '${item.name}: +${formatInventoryQuantity(qty)} '
        '(now ${formatInventoryQuantity(newStock)} ${_unitController.text.trim()})',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not add stock',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return InventoryReportScaffold(
      title: 'Add Quantity Stock',
      body: _loadingCatalog
          ? const Center(
              child: CircularProgressIndicator(
                color: InventoryReportColors.orange,
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _infoBanner(),
                  const SizedBox(height: 14),
                  if (selected == null) ...[
                    _sectionLabel('Select menu item'),
                    TextField(
                      controller: _itemSearchController,
                      onChanged: (v) => setState(() => _itemQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by item or category…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._filteredCatalog.take(40).map(_itemTile),
                    if (_filteredCatalog.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _catalog.isEmpty
                              ? 'No menu items found. Add items under Menu first.'
                              : 'No items match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                  ] else ...[
                    _selectedItemCard(selected),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _qtyController,
                      label: 'Quantity *',
                      hint: 'e.g. 10',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        if (n == null || n <= 0) {
                          return 'Enter a quantity greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _unitController,
                            label: 'Unit',
                            hint: 'pcs / kg / L',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildField(
                            controller: _priceController,
                            label: 'Purchase / Cost per unit',
                            hint: '0',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _minStockController,
                      label: 'Minimum stock (optional)',
                      hint: 'Low-stock alert level',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _saving ? null : _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Stock date',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          _dateFmt.format(_stockDate),
                          style: const TextStyle(
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _supplierController,
                      label: 'Supplier (optional)',
                      hint: 'Supplier name',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _invoiceController,
                      label: 'Invoice / Reference (optional)',
                      hint: 'INV-001',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _reasonController,
                      label: 'Note (optional)',
                      hint: 'e.g. Weekly purchase',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: InventoryReportColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_box_outlined),
                        label: Text(
                          _saving ? 'Saving…' : 'Add Stock',
                          style: const TextStyle(
                            fontFamily: fontMulishSemiBold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InventoryReportColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: InventoryReportColors.navy.withValues(alpha: 0.12),
        ),
      ),
      child: const Text(
        'Adds quantity for Inventory Reports only. Does not change '
        'Stock Management or menu availability.',
        style: TextStyle(
          fontFamily: fontMulishRegular,
          fontSize: 12,
          color: InventoryReportColors.navy,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: fontMulishBold,
          fontSize: 14,
          color: InventoryReportColors.navy,
        ),
      ),
    );
  }

  Widget _itemTile(InventoryCatalogItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          item.name,
          style: const TextStyle(
            fontFamily: fontMulishSemiBold,
            color: InventoryReportColors.navy,
          ),
        ),
        subtitle: Text(
          '${item.categoryName} · Current: '
          '${formatInventoryQuantity(item.currentStock)} ${item.unit}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _selectItem(item),
      ),
    );
  }

  Widget _selectedItemCard(InventoryCatalogItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontFamily: fontMulishBold,
                    fontSize: 15,
                    color: InventoryReportColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.categoryName} · Current stock: '
                  '${formatInventoryQuantity(item.currentStock)} ${item.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _selected = null;
                      _qtyController.clear();
                    }),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
