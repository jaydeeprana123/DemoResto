import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:dotted_line/dotted_line.dart';

import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/Screens/Dashboard/controllers/dashboard_controller.dart';
import 'package:demo/Screens/Menu/MenuPageView.dart';
import 'package:demo/Screens/Billing/FinalBillingView.dart';

/// DashboardView
///
/// Part of the GetX Repository Pattern.
/// Refactored to be a clean, high-performance [StatelessWidget] observing reactive variables
/// inside the [DashboardController] via the [Obx] wrapper.
class DashboardView extends StatelessWidget {
  DashboardView({Key? key}) : super(key: key);

  // Initialize the controller
  final DashboardController controller = Get.put(DashboardController());

  // Brand color guidelines
  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _green = Color(0xFF4CAF50);
  static const _bg = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final crossCols = screenW > 1200
        ? 5
        : screenW > 900
        ? 4
        : screenW > 600
        ? 3
        : 2;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context),
      body: Obx(() {
        return Stack(
          children: [
            Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: controller.tables.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: _orange,
                          onRefresh: () async => controller.loadMenu(),
                          child: MasonryGridView.count(
                            crossAxisCount: crossCols,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            padding: EdgeInsets.fromLTRB(
                              screenW > 900 ? 16 : 8,
                              8,
                              screenW > 900 ? 16 : 8,
                              100,
                            ),
                            itemCount: controller.getFilteredTableKeys().length,
                            itemBuilder: (context, index) {
                              final tableName = controller
                                  .getFilteredTableKeys()
                                  .elementAt(index);
                              final groups = controller.tables[tableName]!;
                              return _buildTableCard(
                                context,
                                tableName,
                                groups,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
            if (controller.isLoading.value)
              Container(
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(color: _orange),
                ),
              ),
          ],
        );
      }),
      floatingActionButton: _buildFab(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _navy,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.restaurant, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Flavor Flow',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: fontMulishBold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Restaurant Dashboard',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: fontMulishRegular,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Obx(() {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${controller.getFilteredTableKeys().length} tables',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: fontMulishSemiBold,
              ),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          tooltip: 'Sign Out',
          onPressed: () => controller.signOut(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: ['All', 'Tables', 'Take Away'].map((label) {
            final selected = controller.selectedTab.value == label;
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.selectedTab.value = label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? _orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: fontMulishSemiBold,
                        color: selected ? Colors.white : Colors.white60,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.table_restaurant_outlined,
              size: 56,
              color: _orange,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tables yet',
            style: TextStyle(
              fontSize: 18,
              fontFamily: fontMulishBold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add tables from the Table tab\nor use the Take Away button below',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: fontMulishRegular,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: SvgPicture.asset(
        icon_take_away,
        width: 22,
        height: 22,
        color: Colors.white,
      ),
      label: const Text(
        'Take Away',
        style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 14),
      ),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MenuPageView(
              menuList: controller.menu,
              tableName: "Take Away ${controller.tableNo + 1}",
              tableNameEditable: true,
              initialItems: [],
              showBilling: true,
              isFromFinalBilling: false,
              isEditMode: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    String tableName,
    List<List<Map<String, dynamic>>> groups,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tables')
          .where('name', isEqualTo: tableName)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        bool isPaid = false;
        String docId = "";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data();
          isPaid = (data['isPaid'] == true);
          docId = doc.id;
        }

        return DragTarget<String>(
          onAccept: (sourceTable) async {
            if (sourceTable != tableName) {
              await controller.mergeTables(
                sourceTable: sourceTable,
                destTable: tableName,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Moved all items from $sourceTable to $tableName',
                  ),
                ),
              );
            }
          },
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<String>(
              data: tableName,
              feedback: Material(
                elevation: 4,
                color: Colors.transparent,
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.red : Colors.blueAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tableName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _buildTableCardWithContent(
                  context,
                  tableName,
                  groups,
                  isPaid,
                  docId,
                ),
              ),
              child: _buildTableCardWithContent(
                context,
                tableName,
                groups,
                isPaid,
                docId,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTableCardWithContent(
    BuildContext context,
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isPaid,
    String docId,
  ) {
    final hasItems = groups.isNotEmpty;
    final isTakeAway = !tableName.contains('Table');
    final headerColor = isPaid
        ? Colors.red.shade700
        : hasItems
        ? _green
        : isTakeAway
        ? _navy
        : _orange;

    final totalQty = groups
        .expand((g) => g)
        .fold<int>(
          0,
          (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1),
        );

    return GestureDetector(
      onDoubleTap: () async {
        if (isPaid) {
          showServedDialog(context, tableName, () async {
            if (isTakeAway) {
              await controller.deleteTable(docId);
            } else {
              await controller.updateTableItemsInFirestore(
                tableName: tableName,
                groups: [],
                isBillPaid: false,
              );
            }
          });
          return;
        }
        if (!hasItems) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MenuPageView(
                menuList: controller.menu,
                tableName: tableName,
                tableNameEditable: false,
                initialItems: [],
                showBilling: true,
                isFromFinalBilling: false,
                isEditMode: false,
              ),
            ),
          );
          return;
        }
        final merged = controller.mergeItemsByNameAndCategory(
          groups.expand((g) => g).toList(),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalBillingView(
              menuData: merged,
              totalMenuList: controller.menu,
              tableName: tableName,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isTakeAway
                        ? Icons.delivery_dining_outlined
                        : Icons.table_restaurant_outlined,
                    color: Colors.white70,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tableName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontMulishBold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasItems && !isPaid)
                    _cardIconBtn(Icons.edit_outlined, () async {
                      final lastGroup = groups.last;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuPageView(
                            menuList: controller.menu,
                            tableName: tableName,
                            tableNameEditable: false,
                            initialItems: List<Map<String, dynamic>>.from(
                              lastGroup,
                            ),
                            showBilling: groups.length == 1,
                            isFromFinalBilling: false,
                            isEditMode: true,
                          ),
                        ),
                      );
                    }),
                  if (!isPaid)
                    _cardIconBtn(Icons.add_circle_outline, () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MenuPageView(
                            menuList: controller.menu,
                            tableName: tableName,
                            tableNameEditable: false,
                            initialItems: [],
                            showBilling: !hasItems,
                            isFromFinalBilling: false,
                            isEditMode: false,
                          ),
                        ),
                      );
                    }),
                  if (isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PAID',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontFamily: fontMulishBold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!hasItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: Colors.grey.shade300,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Double-tap to order',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontFamily: fontMulishRegular,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(groups.length, (gi) {
                      final group = groups[gi];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...group.map((item) {
                            final qty = (item['qty'] as num?)?.toInt() ?? 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontFamily: fontMulishRegular,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _orange.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '×$qty',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _orange,
                                        fontFamily: fontMulishBold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (gi < groups.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: DottedLine(
                                dashColor: Colors.grey.shade300,
                                lineThickness: 1,
                                dashLength: 4,
                                dashGapLength: 4,
                              ),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade200,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$totalQty item${totalQty != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontFamily: fontMulishSemiBold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, color: Colors.white70, size: 18),
    ),
  );

  void showServedDialog(
    BuildContext context,
    String tableName,
    VoidCallback onServed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tableName.contains("Take Away")
                ? "Mark as Delivered?"
                : "Mark as Served?",
            style: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 18,
            ),
          ),
          content: Text(
            tableName.contains("Take Away")
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
                tableName.contains("Take Away") ? "Delivered" : "Served",
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
}
