import 'package:smartKitchen/features/inventory_reports/views/add_quantity_stock_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/current_stock_report_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/inventory_dashboard_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/inventory_valuation_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/item_consumption_report_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/low_stock_report_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/stock_in_report_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/stock_movement_report_page.dart';
import 'package:smartKitchen/features/inventory_reports/views/wastage_report_page.dart';
import 'package:smartKitchen/features/inventory_reports/widgets/inventory_report_widgets.dart';
import 'package:smartKitchen/features/settings/views/settings_ui.dart';
import 'package:smartKitchen/Styles/my_font.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InventoryReportsHubPage extends StatelessWidget {
  const InventoryReportsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return InventoryReportScaffold(
      title: 'Inventory Reports',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsGroupedSection(
            children: [
              SettingsNavRow(
                icon: Icons.add_box_rounded,
                title: 'Add Quantity Stock',
                subtitle: 'Stock in for inventory quantity & valuation reports',
                onTap: () => Get.to(() => const AddQuantityStockPage()),
              ),
              SettingsNavRow(
                icon: Icons.dashboard_outlined,
                title: 'Inventory Dashboard',
                subtitle: 'Summary cards, stock in/out & top consumed items',
                onTap: () => Get.to(() => const InventoryDashboardPage()),
              ),
              SettingsNavRow(
                icon: Icons.inventory_outlined,
                title: 'Current Stock',
                subtitle: 'Opening, movements & current stock by item',
                onTap: () => Get.to(() => const CurrentStockReportPage()),
              ),
              SettingsNavRow(
                icon: Icons.swap_horiz_rounded,
                title: 'Stock Movement',
                subtitle: 'All inventory movements with filters',
                onTap: () => Get.to(() => const StockMovementReportPage()),
              ),
              SettingsNavRow(
                icon: Icons.add_box_outlined,
                title: 'Stock In',
                subtitle: 'Purchases and stock received',
                onTap: () => Get.to(() => const StockInReportPage()),
              ),
              SettingsNavRow(
                icon: Icons.delete_outline,
                title: 'Wastage Report',
                subtitle: 'Expired, damaged & other wastage',
                onTap: () => Get.to(() => const WastageReportPage()),
              ),
              SettingsNavRow(
                icon: Icons.warning_amber_rounded,
                title: 'Low Stock Report',
                subtitle: 'Items at or below minimum stock',
                onTap: () => Get.to(() => const LowStockReportPage()),
              ),
              SettingsNavRow(
                icon: Icons.payments_outlined,
                title: 'Inventory Valuation',
                subtitle: 'Current stock value by item',
                onTap: () => Get.to(() => const InventoryValuationPage()),
              ),
              SettingsNavRow(
                icon: Icons.trending_down_rounded,
                title: 'Item Consumption',
                subtitle: 'Sold qty, revenue & gross profit',
                onTap: () => Get.to(() => const ItemConsumptionReportPage()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: InventoryReportColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: InventoryReportColors.navy.withValues(alpha: 0.12),
              ),
            ),
            child: const Text(
              'Quantity stock is separate from Stock Management. Adding stock '
              'here does not change menu availability.',
              style: TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 12,
                color: InventoryReportColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
