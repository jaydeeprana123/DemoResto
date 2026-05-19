import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:demo/Screens/Orders/CartPageView.dart';
import 'package:demo/MyWidgets/EditableTextField.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/services/ai_order_service.dart'; // Holds OrderResult
import 'package:demo/models/agent_response.dart';
import 'package:demo/Screens/Menu/controllers/restaurant_menu_controller.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1A3A5C);
const _kOrange = Color(0xFFf57c35);

/// MenuPageView
///
/// Refactored to leverage the GetX Repository Pattern.
/// The presenting UI acts as a pure presentation layer that communicates with
/// the tagged [RestaurantMenuController] to reactively observe menu items, category filters,
/// voice order transcription states, and order cart checkouts.
class MenuPageView extends StatefulWidget {
  final List<Map<String, dynamic>> menuList; // Catalog menu list
  final List<Map<String, dynamic>> initialItems;
  final String tableName;
  final bool tableNameEditable;
  final bool showBilling;
  final bool isFromFinalBilling;
  final bool isEditMode;

  const MenuPageView({
    required this.menuList,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    required this.isFromFinalBilling,
    required this.isEditMode,
    this.initialItems = const [],
    Key? key,
  }) : super(key: key);

  @override
  State<MenuPageView> createState() => _MenuPageViewState();
}

class _MenuPageViewState extends State<MenuPageView> {
  late final RestaurantMenuController controller;

  @override
  void initState() {
    super.initState();
    // Register controller uniquely using the table name as tag
    controller = Get.put(RestaurantMenuController(), tag: widget.tableName);
    controller.initializeMenuData(
      menuList: widget.menuList,
      initialItems: widget.initialItems,
      initialTableName: widget.tableName,
    );
  }

  // ── Calculated Getters ────────────────────────────────────────────────────

  int get totalItems {
    int total = 0;
    controller.menuData.forEach((_, items) {
      for (var item in items) total += (item['qty'] as int);
    });
    return total;
  }

  double get totalPrice {
    double total = 0.0;
    controller.menuData.forEach((_, items) {
      for (var item in items) {
        total += (item['qty'] as int) * (item['price'] as num);
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = controller.menuData.keys.toList();
      final isFiltering =
          !controller.showAllCategories.value &&
          controller.selectedCategories.isNotEmpty;

      return DefaultTabController(
        length: controller.showAllCategories.value
            ? categories.length
            : controller.selectedCategories.length,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: _kNavy,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: controller.showSearch.value
                ? TextField(
                    controller: controller.searchController,
                    autofocus: true,
                    onChanged: (value) {
                      controller.searchQuery.value = value.toLowerCase();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search menu...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: fontMulishRegular,
                    ),
                  )
                : Row(
                    children: [
                      (widget.tableName.contains("Table") ||
                              !widget.tableNameEditable)
                          ? Text(
                              controller.tableName.value,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: fontMulishBold,
                                color: Colors.white,
                              ),
                            )
                          : Expanded(
                              child: EditableTextField(
                                controller: controller.tableNameController,
                                onEditingChanged: (value) {
                                  controller.isNameEdit.value = value;
                                },
                              ),
                            ),
                    ],
                  ),
            actions: [
              if (!controller.isNameEdit.value)
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.redAccent),
                  onPressed: () => _startVoiceOrder(context),
                  tooltip: "Voice Order",
                ),
              if (!controller.isNameEdit.value)
                IconButton(
                  icon: Icon(
                    controller.showSearch.value ? Icons.close : Icons.search,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (controller.showSearch.value) {
                      controller.searchQuery.value = '';
                      controller.searchController.clear();
                    }
                    controller.showSearch.value = !controller.showSearch.value;
                  },
                ),
              if (!controller.isNameEdit.value)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () => _showCategoryFilterDialog(context),
                      tooltip: "Filter by Category",
                    ),
                    if (isFiltering)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _kOrange,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              '${controller.selectedCategories.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: fontMulishBold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
            bottom: !controller.showSearch.value
                ? TabBar(
                    isScrollable: true,
                    indicatorColor: _kOrange,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontFamily: fontMulishSemiBold,
                      fontSize: 13,
                    ),
                    tabs: controller.showAllCategories.value
                        ? categories.map((c) => Tab(text: c)).toList()
                        : controller.selectedCategories
                              .map((c) => Tab(text: c))
                              .toList(),
                  )
                : null,
          ),
          body: Column(
            children: [
              Expanded(
                child: controller.showSearch.value
                    ? _buildGlobalSearchList()
                    : controller.showAllCategories.value
                    ? TabBarView(
                        children: categories.map((category) {
                          final items = controller.menuData[category]!;

                          return ListView.builder(
                            itemCount: items.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) =>
                                _buildMenuItem(category, index),
                          );
                        }).toList(),
                      )
                    : TabBarView(
                        children: controller.selectedCategories.map((category) {
                          final items = controller.menuData[category];

                          return ListView.builder(
                            itemCount: items?.length ?? 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) =>
                                _buildMenuItem(category, index),
                          );
                        }).toList(),
                      ),
              ),

              // Bottom cart checkout panel
              if (totalItems > 0)
                InkWell(
                  onTap: () {
                    final selectedItems = controller.getSelectedItems();

                    if (widget.isFromFinalBilling) {
                      Navigator.pop(context, selectedItems);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CartPageView(
                            tableName: controller.tableNameController.text,
                            tableNameEditable: widget.tableNameEditable,
                            menuData: selectedItems,
                            fullMenu: widget.menuList,
                            overallRemarks: controller.overallRemarks.value,
                            isEditMode: widget.isEditMode,
                            showBilling: widget.showBilling,
                          ),
                        ),
                      ).then((onValue) {
                        if (onValue != null) {
                          List<Map<String, dynamic>> changedItems = onValue;

                          // Synchronize items and quantities back to catalog
                          for (var category in controller.menuData.keys) {
                            for (var item in controller.menuData[category]!) {
                              final existingItem = changedItems.firstWhere(
                                (e) => e['name'] == item['name'],
                                orElse: () => {},
                              );
                              if (existingItem.isNotEmpty) {
                                item['qty'] = existingItem['qty'];
                                item['remarks'] = existingItem['remarks'] ?? '';
                              } else {
                                item['qty'] = 0;
                              }
                            }
                          }
                          controller.menuData.refresh();
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: primary_color,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$totalItems items | ₹${totalPrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              "View Cart",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontFamily: fontMulishBold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  // ── Search list helpers ───────────────────────────────────────────────────

  Widget _buildGlobalSearchList() {
    final allItems = <Map<String, dynamic>>[];
    final sourceCategories = controller.showAllCategories.value
        ? controller.menuData.keys
        : controller.selectedCategories;

    for (var category in sourceCategories) {
      allItems.addAll(controller.menuData[category]!);
    }

    final filtered = allItems.where((item) {
      final name = item['name'].toString().toLowerCase();
      return name.contains(controller.searchQuery.value);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No matching items found.',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final category = item['category'];
        final qty = item['qty'] as int;
        return _buildMenuTile(category, index, item, qty);
      },
    );
  }

  Widget _buildMenuTile(
    String category,
    int index,
    Map<String, dynamic> item,
    int qty,
  ) {
    return InkWell(
      onTap: () {
        controller.addItemDirectly(item);
      },
      onLongPress: () {
        _showRemarkEditSheet(
          context,
          category,
          index,
          isFromSearch: true,
          searchItem: item,
        );
      },
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 2,
              horizontal: 16,
            ),
            title: Text(
              item['name'],
              style: const TextStyle(
                fontSize: 14,
                color: text_color,
                fontFamily: fontMulishSemiBold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Row(
                children: [
                  Text(
                    "₹${item['price'].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: secondary_text_color,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (qty > 0)
                    Text(
                      "\u00D7$qty",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontFamily: fontMulishBold,
                      ),
                    ),
                ],
              ),
            ),
            trailing: qty == 0
                ? GestureDetector(
                    onTap: () {
                      controller.addItemDirectly(item);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black87, width: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Add",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // Absorb stray taps
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            controller.removeItemDirectly(item);
                          },
                        ),
                        Text(
                          "$qty",
                          style: const TextStyle(
                            fontSize: 14,
                            color: text_color,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            controller.addItemDirectly(item);
                          },
                        ),
                      ],
                    ),
                  ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 0.5,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  // ── Menu item card helper ────────────────────────────────────────────────

  Widget _buildMenuItem(String category, int index) {
    final item = controller.menuData[category]![index];
    final qty = item['qty'] as int;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                controller.incrementQty(category, index);
              },
              onLongPress: () {
                _showRemarkEditSheet(context, category, index);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: fontMulishBold,
                      color: Color(0xFF1A3A5C),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₹${(item['price'] as num).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                  if (item['remarks'] != null &&
                      item['remarks'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '* ${item['remarks']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade400,
                          fontStyle: FontStyle.italic,
                          fontFamily: fontMulishSemiBold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          qty == 0
              ? _addButton(
                  onTap: () => controller.incrementQty(category, index),
                )
              : _stepper(
                  qty: qty,
                  onDecrement: () => controller.decrementQty(category, index),
                  onIncrement: () => controller.incrementQty(category, index),
                ),
        ],
      ),
    );
  }

  Widget _addButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFf57c35), width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            fontSize: 13,
            fontFamily: fontMulishBold,
            color: Color(0xFFf57c35),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _stepper({
    required int qty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 45,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: fontMulishBold,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 45,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFf57c35),
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(20),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Modals & Dialogs ─────────────────────────────────────────────────────

  void _showRemarkEditSheet(
    BuildContext context,
    String category,
    int index, {
    bool isFromSearch = false,
    Map<String, dynamic>? searchItem,
  }) {
    final item = isFromSearch
        ? searchItem!
        : controller.menuData[category]![index];
    final ctrl = TextEditingController(
      text: (item['remarks'] ?? '').toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'].toString(),
              style: const TextStyle(
                fontSize: 15,
                fontFamily: fontMulishBold,
                color: Color(0xFF1A3A5C),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Add instructions (e.g. less spicy, extra cheese)...',
                hintStyle: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 13,
                ),
                suffixIcon: Icon(
                  Icons.edit_note,
                  color: Colors.orange.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFf57c35),
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: Colors.orange.shade50,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  item['remarks'] = ctrl.text.trim();
                  controller.menuData.refresh();
                  Navigator.pop(ctx);
                  ctrl.dispose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Save Remark',
                  style: TextStyle(fontFamily: fontMulishBold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sarvam STT Audio Recording Sheet ──────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startVoiceOrder(BuildContext context) async {
    final hasPerms = await controller.hasMicrophonePermission();
    if (!hasPerms) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return Obx(() {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Mic icon with amplitude ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (controller.isRecording.value)
                      Container(
                        width: 56 + (controller.currentAmplitude.value * 20),
                        height: 56 + (controller.currentAmplitude.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(
                            0.15 + controller.currentAmplitude.value * 0.15,
                          ),
                        ),
                      ),
                    Icon(
                      controller.isRecording.value ? Icons.mic : Icons.mic_none,
                      size: 40,
                      color: controller.isRecording.value
                          ? Colors.red
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title + subtitles
                const Text(
                  'Voice Order',
                  style: TextStyle(
                    fontSize: 17,
                    fontFamily: fontMulishBold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.isRecording.value
                      ? '🔴 Recording ${_formatDuration(controller.recordingSeconds.value)} — speak your order'
                      : controller.isTranscribing.value
                      ? '⏳ Transcribing with Sarvam AI…'
                      : controller.recognizedText.value.isNotEmpty
                      ? 'Transcript ready'
                      : 'Tap Start, then speak your full order',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: controller.isRecording.value
                        ? Colors.red.shade700
                        : controller.isTranscribing.value
                        ? Colors.blue.shade700
                        : Colors.grey.shade600,
                    fontFamily: fontMulishRegular,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by Sarvam AI • Hindi, Gujarati, English',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontFamily: fontMulishRegular,
                  ),
                ),
                const SizedBox(height: 14),

                // Transcription area
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 64,
                    maxHeight: 120,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: controller.isRecording.value
                        ? Colors.red.shade50
                        : controller.isTranscribing.value
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: controller.isRecording.value
                          ? Colors.red.shade200
                          : controller.isTranscribing.value
                          ? Colors.blue.shade200
                          : Colors.grey.shade300,
                      width:
                          controller.isRecording.value ||
                              controller.isTranscribing.value
                          ? 1.5
                          : 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: controller.isRecording.value
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(7, (i) {
                                    final barHeight =
                                        8.0 +
                                        (controller.currentAmplitude.value *
                                            24 *
                                            (i.isEven ? 1.0 : 0.6));
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: 4,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Speak items, quantities & remarks…',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade300,
                                    fontFamily: fontMulishRegular,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : controller.isTranscribing.value
                        ? Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Recognising speech…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade600,
                                    fontFamily: fontMulishRegular,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            controller.recognizedText.value.isEmpty
                                ? 'e.g. "do chicken tikka rice aur teen malai tikka less spicy"'
                                : controller.recognizedText.value,
                            style: TextStyle(
                              fontSize: 13,
                              color: controller.recognizedText.value.isEmpty
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              fontFamily: fontMulishRegular,
                              fontStyle: controller.recognizedText.value.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),

                // AI Processing Alert
                if (controller.isProcessing.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Processing with AI…',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Dialog action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            (controller.isProcessing.value ||
                                controller.isTranscribing.value)
                            ? null
                            : () async {
                                await controller.cancelVoiceRecording();
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child:
                          (controller.isProcessing.value ||
                              controller.isTranscribing.value)
                          ? ElevatedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              label: Text(
                                controller.isTranscribing.value
                                    ? 'Transcribing…'
                                    : 'Processing…',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: controller.isTranscribing.value
                                    ? Colors.blue.shade600
                                    : Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            )
                          : controller.isRecording.value
                          ? ElevatedButton.icon(
                              onPressed: () async {
                                final text = await controller
                                    .stopVoiceRecording();
                                if (text != null && text.trim().isNotEmpty) {
                                  final response = await controller
                                      .processInputAgent(text);
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  _routeAgentResponse(context, response, text);
                                } else {
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not recognise speech. Please try again.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.stop_circle_outlined,
                                size: 20,
                              ),
                              label: const Text('Stop & Process'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () async {
                                await controller.startVoiceRecording();
                              },
                              icon: const Icon(Icons.mic, size: 20),
                              label: Text(
                                controller.recognizedText.value.isEmpty
                                    ? 'Start'
                                    : 'Retry',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _routeAgentResponse(
    BuildContext context,
    AgentResponse response,
    String transcript,
  ) {
    switch (response.action) {
      case AgentAction.auto:
        _showVoiceOrderDialog(
          context: context,
          items: response.items,
          title: 'Voice Order Recognised',
          isSuggestion: false,
          transcript: transcript,
        );
        break;

      case AgentAction.suggest:
        _showVoiceOrderDialog(
          context: context,
          items: response.suggestions,
          title: response.message,
          isSuggestion: true,
          confidence: response.confidence,
          transcript: transcript,
        );
        break;

      case AgentAction.retry:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎤 ${response.message}'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: () => _startVoiceOrder(context),
            ),
          ),
        );
        break;
    }
  }

  void _showVoiceOrderDialog({
    required BuildContext context,
    required List<OrderResult> items,
    required String title,
    required bool isSuggestion,
    double confidence = 1.0,
    String transcript = '',
  }) {
    if (items.isEmpty) return;

    final editableItems = List<OrderResult>.from(items);
    final remarkControllers = editableItems
        .map((r) => TextEditingController(text: r.remarks))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                    decoration: BoxDecoration(
                      color: isSuggestion
                          ? Colors.orange.shade700
                          : const Color(0xFF1A3A5C),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuggestion ? Icons.help_outline : Icons.mic,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontFamily: fontMulishBold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isSuggestion)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade50,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Text(
                        'AI Confidence: ${(confidence * 100).toStringAsFixed(0)}%  •  Review items below',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontFamily: fontMulishRegular,
                        ),
                      ),
                    ),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: editableItems.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.remove_shopping_cart,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'All items removed.\nTap Cancel or try again.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontFamily: fontMulishRegular,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: editableItems.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, i) {
                              final item = editableItems[i];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.item['name'].toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontFamily: fontMulishBold,
                                              color: Color(0xFF1A3A5C),
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  if (editableItems[i]
                                                          .quantity >
                                                      1) {
                                                    editableItems[i] =
                                                        OrderResult(
                                                          item: item.item,
                                                          quantity:
                                                              item.quantity - 1,
                                                          remarks:
                                                              remarkControllers[i]
                                                                  .text,
                                                        );
                                                  } else {
                                                    editableItems.removeAt(i);
                                                    remarkControllers.removeAt(
                                                      i,
                                                    );
                                                  }
                                                });
                                              },
                                            ),
                                            Text(
                                              '${item.quantity}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: fontMulishBold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  editableItems[i] =
                                                      OrderResult(
                                                        item: item.item,
                                                        quantity:
                                                            item.quantity + 1,
                                                        remarks:
                                                            remarkControllers[i]
                                                                .text,
                                                      );
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: remarkControllers[i],
                                      decoration: InputDecoration(
                                        hintText: 'Remarks (e.g. less spicy)',
                                        hintStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () => _startVoiceOrder(context),
                              );
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: editableItems.isEmpty
                                ? null
                                : () {
                                    final updated = List.generate(
                                      editableItems.length,
                                      (i) => OrderResult(
                                        item: editableItems[i].item,
                                        quantity: editableItems[i].quantity,
                                        remarks: remarkControllers[i].text
                                            .trim(),
                                      ),
                                    );
                                    if (transcript.isNotEmpty) {
                                      if (controller
                                          .overallRemarks
                                          .value
                                          .isNotEmpty) {
                                        controller.overallRemarks.value += '\n';
                                      }
                                      controller.overallRemarks.value +=
                                          transcript;
                                    }

                                    Navigator.pop(dialogCtx);
                                    controller.applyOrderResults(updated);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ ${updated.length} item(s) added to cart',
                                        ),
                                        backgroundColor: Colors.green.shade700,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(
                              editableItems.isEmpty
                                  ? 'Nothing to add'
                                  : 'Add to Cart',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final c in remarkControllers) c.dispose();
    });
  }

  void _showCategoryFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Obx(() {
          final categories = controller.menuData.keys.toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Filter by Category",
              style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text(
                      "All Categories",
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 15,
                      ),
                    ),
                    value: controller.showAllCategories.value,
                    activeColor: Colors.green,
                    onChanged: (bool? value) {
                      controller.showAllCategories.value = value ?? true;
                      if (controller.showAllCategories.value) {
                        controller.selectedCategories.clear();
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final categoryName = categories[index];
                        final isSelected = controller.selectedCategories
                            .contains(categoryName);

                        return CheckboxListTile(
                          title: Text(
                            categoryName,
                            style: const TextStyle(
                              fontFamily: fontMulishRegular,
                              fontSize: 14,
                            ),
                          ),
                          value: isSelected,
                          activeColor: Colors.green,
                          enabled: !controller.showAllCategories.value,
                          onChanged: controller.showAllCategories.value
                              ? null
                              : (bool? value) {
                                  if (value == true) {
                                    controller.selectedCategories.add(
                                      categoryName,
                                    );
                                  } else {
                                    controller.selectedCategories.remove(
                                      categoryName,
                                    );
                                  }
                                },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.selectedCategories.clear();
                  controller.showAllCategories.value = true;
                  controller.saveSelectedCategories();
                  setState(() {});
                },
                child: const Text(
                  "Clear",
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  controller.saveSelectedCategories();
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text(
                  "Apply",
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}
