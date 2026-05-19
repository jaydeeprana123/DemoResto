import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/models/GroupOrder.dart';
import 'package:demo/Screens/Kitchen/controllers/kitchen_controller.dart';

/// KitchenOrdersListView
/// 
/// Part of the GetX Repository Pattern.
/// Refactored to be a clean [StatelessWidget] observing reactive order lists
/// and filters inside the [KitchenController].
class KitchenOrdersListView extends StatelessWidget {
  const KitchenOrdersListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate or find the KitchenController
    final KitchenController controller = Get.put(KitchenController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C), // Navy brand color
        elevation: 0,
        title: const Text(
          "All Orders",
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        actions: [
          // Filter button with reactive badge count
          Obx(() {
            final activeCount = controller.selectedCategories.length;
            final isFiltering = !controller.showAllCategories.value && activeCount > 0;

            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: () => _showCategoryFilterDialog(context, controller),
                  tooltip: "Filter by Category",
                ),
                if (isFiltering)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$activeCount',
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
            );
          }),
        ],
      ),
      body: Obx(() {
        final filteredGroups = controller.filteredOrders;

        if (filteredGroups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  controller.showAllCategories.value
                      ? "No orders found"
                      : "No orders in selected categories",
                  style: const TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                if (!controller.showAllCategories.value && controller.selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Selected: ${controller.selectedCategories.join(', ')}",
                    style: const TextStyle(
                      fontFamily: fontMulishRegular,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        }

        final screenW = MediaQuery.of(context).size.width;
        final crossCols = screenW > 1200 ? 5
            : screenW > 900  ? 4
            : screenW > 600  ? 3
            : screenW > 400  ? 2
            : 1;

        return MasonryGridView.count(
          crossAxisCount: crossCols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          padding: const EdgeInsets.all(12),
          itemCount: filteredGroups.length,
          itemBuilder: (context, index) {
            final group = filteredGroups[index];
            final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
            final isBlinking = controller.blinkingGroupKey.value == group.key.hashCode;
            final blinkMode = controller.blinkingColorMode.value;
            final isOld = DateTime.now().difference(time).inMinutes > 5;

            Color cardBgColor = Colors.white;
            if (isBlinking) {
              if (blinkMode == 'green') {
                cardBgColor = const Color(0xFFE8F5E9); // Curated premium soft green
              } else if (blinkMode == 'blue') {
                cardBgColor = const Color(0xFFE3F2FD); // Curated premium soft blue
              }
            }

            Border cardBorder;
            if (isBlinking) {
              if (blinkMode == 'green') {
                cardBorder = Border.all(color: Colors.green.shade400, width: 2);
              } else {
                cardBorder = Border.all(color: Colors.blue.shade400, width: 2);
              }
            } else if (isOld) {
              cardBorder = Border.all(color: Colors.red, width: 2);
            } else {
              cardBorder = Border.all(color: Colors.grey.shade200);
            }

            // Automatically clear Take Away orders that have been paid and are delayed (old)
            if (group.tableName.contains("Take Away") && isOld && group.isPaid) {
              controller.deleteTable(group.docId);
            }

            return GestureDetector(
              onDoubleTap: () {
                if (group.isPaid && controller.selectedCategories.isEmpty) {
                  showServedDialog(context, group.tableName, () async {
                    controller.playDeleteSound();
                    if (group.tableName.contains("Take Away")) {
                      await controller.deleteTable(group.docId);
                    } else {
                      await controller.updateTableItems(group.tableName, [], false);
                    }
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isOld ? Colors.red.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: cardBorder,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Order Card Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A3A5C), // Brand Navy
                        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  group.tableName.contains("Take Away")
                                      ? icon_packing
                                      : icon_table,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  width: group.tableName.contains("Take Away") ? 18 : 22,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    group.tableName,
                                    style: TextStyle(
                                      fontFamily: group.tableName.contains("Take Away")
                                          ? fontMulishBold
                                          : fontMulishSemiBold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (group.isPaid)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "PAID",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontFamily: fontMulishBold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Elapsed duration indicators
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isOld ? Colors.red.shade50 : const Color(0xFFF5F6FA),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: isOld ? Colors.red : Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            formatRelativeTime(time),
                            style: TextStyle(
                              fontFamily: fontMulishSemiBold,
                              fontSize: 13,
                              color: isOld ? Colors.red : Colors.grey.shade800,
                            ),
                          ),
                          if (isOld) ...[
                            const Spacer(),
                            const Text(
                              "DELAYED",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontFamily: fontMulishBold,
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                    // Order item list representation
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: group.items.map((item) {
                          final qty = item['qty'] ?? 1;
                          final remarks = item['remarks']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf57c35).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFf57c35).withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    "${qty}x",
                                    style: const TextStyle(
                                      color: Color(0xFFf57c35), // Brand Orange
                                      fontFamily: fontMulishBold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontFamily: fontMulishSemiBold,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (remarks.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            "* $remarks",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade400,
                                              fontFamily: fontMulishSemiBold,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// Calculates a user-friendly elapsed duration string since the order was placed.
  String formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min${difference.inMinutes > 1 ? "s" : ""} ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hr${difference.inHours > 1 ? "s" : ""} ago";
    } else if (difference.inDays == 1) {
      return "yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago";
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(time);
    }
  }

  /// Prompts a served/delivered dialog upon double-tapping paid table headers.
  void showServedDialog(
    BuildContext context,
    String tableName,
    VoidCallback onServed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isTakeAway = tableName.contains("Take Away");
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isTakeAway ? "Mark as Delivered?" : "Mark as Served?",
            style: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
          ),
          content: Text(
            isTakeAway
                ? "Are you sure you want to mark table '$tableName' as delivered?"
                : "Are you sure you want to mark table '$tableName' as served?",
            style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
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
                Navigator.pop(context);
                onServed();
              },
              child: Text(
                isTakeAway ? "Delivered" : "Served",
                style: const TextStyle(
                  fontFamily: fontMulishSemiBold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Category filter modal built reactively directly from KitchenController observables.
  void _showCategoryFilterDialog(BuildContext context, KitchenController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Obx(() {
          if (controller.categoriesList.isEmpty) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Filter by Category",
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 18,
                ),
              ),
              content: const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Filter by Category",
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 18,
              ),
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
                      itemCount: controller.categoriesList.length,
                      itemBuilder: (context, index) {
                        final categoryName = controller.categoriesList[index];
                        final isSelected = controller.selectedCategories.contains(categoryName);

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
                                    controller.selectedCategories.add(categoryName);
                                  } else {
                                    controller.selectedCategories.remove(categoryName);
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
                  Navigator.pop(context);
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
