import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';

enum InventoryMovementType {
  stockIn('Stock In'),
  sale('Sale/Consumption'),
  wastage('Wastage'),
  adjustment('Manual Adjustment'),
  returnItem('Return');

  const InventoryMovementType(this.label);
  final String label;

  static InventoryMovementType? fromFirestore(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.toLowerCase().replaceAll(' ', '_');
    for (final type in values) {
      if (type.name == normalized ||
          type.label.toLowerCase() == value.toLowerCase() ||
          _aliases[normalized] == type) {
        return type;
      }
    }
    return null;
  }

  String get firestoreValue => switch (this) {
        InventoryMovementType.stockIn => 'stock_in',
        InventoryMovementType.sale => 'sale',
        InventoryMovementType.wastage => 'wastage',
        InventoryMovementType.adjustment => 'adjustment',
        InventoryMovementType.returnItem => 'return',
      };

  static const _aliases = <String, InventoryMovementType>{
    'stock_in': InventoryMovementType.stockIn,
    'stockin': InventoryMovementType.stockIn,
    'consumption': InventoryMovementType.sale,
    'sale_consumption': InventoryMovementType.sale,
    'manual_adjustment': InventoryMovementType.adjustment,
    'return': InventoryMovementType.returnItem,
  };
}

enum InventoryStockStatus {
  inStock('In Stock'),
  lowStock('Low Stock'),
  outOfStock('Out of Stock');

  const InventoryStockStatus(this.label);
  final String label;
}

enum WastageReason {
  expired('Expired'),
  damaged('Damaged'),
  overproduction('Overproduction'),
  spillage('Spillage'),
  kitchenMistake('Kitchen Mistake'),
  other('Other');

  const WastageReason(this.label);
  final String label;

  static WastageReason? fromFirestore(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.toLowerCase().replaceAll(' ', '_');
    for (final reason in values) {
      if (reason.name == normalized ||
          reason.label.toLowerCase() == value.toLowerCase()) {
        return reason;
      }
    }
    return WastageReason.other;
  }
}

enum ConsumptionSortOption {
  highestConsumption('Highest Consumption'),
  lowestConsumption('Lowest Consumption'),
  highestRevenue('Highest Revenue'),
  highestProfit('Highest Profit');

  const ConsumptionSortOption(this.label);
  final String label;
}

class InventoryCatalogItem {
  const InventoryCatalogItem({
    required this.menuItemKey,
    required this.categoryId,
    required this.categoryName,
    required this.itemId,
    required this.name,
    this.unit = 'pcs',
    this.sellingPrice = 0,
    this.costPerUnit = 0,
    this.currentStock = 0,
    this.minimumStock = 0,
  });

  final String menuItemKey;
  final String categoryId;
  final String categoryName;
  final String itemId;
  final String name;
  final String unit;
  final double sellingPrice;
  final double costPerUnit;
  final double currentStock;
  final double minimumStock;

  InventoryCatalogItem copyWith({
    double? currentStock,
    double? minimumStock,
    double? costPerUnit,
    String? unit,
  }) {
    return InventoryCatalogItem(
      menuItemKey: menuItemKey,
      categoryId: categoryId,
      categoryName: categoryName,
      itemId: itemId,
      name: name,
      unit: unit ?? this.unit,
      sellingPrice: sellingPrice,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
    );
  }
}

class InventoryMovementRecord {
  const InventoryMovementRecord({
    required this.id,
    required this.menuItemKey,
    required this.itemName,
    required this.categoryName,
    required this.movementType,
    required this.quantity,
    required this.previousStock,
    required this.currentStock,
    this.reason,
    this.supplier,
    this.purchasePrice,
    this.unit,
    this.invoiceNumber,
    this.addedBy = 'System',
    this.createdAt,
    this.isSynthetic = false,
    this.wastageReason,
  });

  final String id;
  final String menuItemKey;
  final String itemName;
  final String categoryName;
  final InventoryMovementType movementType;
  final double quantity;
  final double previousStock;
  final double currentStock;
  final String? reason;
  final String? supplier;
  final double? purchasePrice;
  final String? unit;
  final String? invoiceNumber;
  final String addedBy;
  final DateTime? createdAt;
  final bool isSynthetic;
  final WastageReason? wastageReason;

  double get totalCost =>
      purchasePrice == null ? 0 : quantity.abs() * purchasePrice!;

  factory InventoryMovementRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return InventoryMovementRecord(
      id: doc.id,
      menuItemKey: data['menuItemKey']?.toString() ?? '',
      itemName: data['itemName']?.toString() ?? '',
      categoryName: data['categoryName']?.toString() ?? '',
      movementType:
          InventoryMovementType.fromFirestore(data['movementType']?.toString()) ??
              InventoryMovementType.adjustment,
      quantity: _asDouble(data['quantity']),
      previousStock: _asDouble(data['previousStock']),
      currentStock: _asDouble(data['currentStock']),
      reason: data['reason']?.toString(),
      supplier: data['supplier']?.toString(),
      purchasePrice: _nullableDouble(data['purchasePrice']),
      unit: data['unit']?.toString(),
      invoiceNumber: data['invoiceNumber']?.toString(),
      addedBy: data['addedBy']?.toString() ?? 'Unknown',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      wastageReason:
          WastageReason.fromFirestore(data['wastageReason']?.toString()),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class CurrentStockRow {
  const CurrentStockRow({
    required this.itemName,
    required this.category,
    required this.openingStock,
    required this.stockIn,
    required this.stockUsed,
    required this.wastage,
    required this.adjustment,
    required this.currentStock,
    required this.minimumStock,
    required this.status,
    required this.unit,
    this.menuItemKey = '',
  });

  final String itemName;
  final String category;
  final double openingStock;
  final double stockIn;
  final double stockUsed;
  final double wastage;
  final double adjustment;
  final double currentStock;
  final double minimumStock;
  final InventoryStockStatus status;
  final String unit;
  final String menuItemKey;
}

class LowStockRow {
  const LowStockRow({
    required this.itemName,
    required this.category,
    required this.currentStock,
    required this.minimumStock,
    required this.unit,
    required this.reorderQuantity,
    required this.status,
  });

  final String itemName;
  final String category;
  final double currentStock;
  final double minimumStock;
  final String unit;
  final double reorderQuantity;
  final InventoryStockStatus status;
}

class ValuationRow {
  const ValuationRow({
    required this.itemName,
    required this.currentQuantity,
    required this.unit,
    required this.costPerUnit,
    required this.totalValue,
  });

  final String itemName;
  final double currentQuantity;
  final String unit;
  final double costPerUnit;
  final double totalValue;
}

class ItemConsumptionRow {
  const ItemConsumptionRow({
    required this.itemName,
    required this.category,
    required this.quantityConsumed,
    required this.revenue,
    required this.estimatedCost,
    required this.grossProfit,
  });

  final String itemName;
  final String category;
  final double quantityConsumed;
  final double revenue;
  final double estimatedCost;
  final double grossProfit;
}

class InventoryDashboardData {
  const InventoryDashboardData({
    required this.range,
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.totalInventoryValue,
    required this.stockInTotal,
    required this.stockOutTotal,
    required this.wastageTotal,
    required this.wastageCost,
    required this.topConsumedItems,
    required this.topWastageItems,
    required this.valuationByCategory,
  });

  final ExportDateRange range;
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalInventoryValue;
  final double stockInTotal;
  final double stockOutTotal;
  final double wastageTotal;
  final double wastageCost;
  final List<ItemConsumptionRow> topConsumedItems;
  final List<InventoryMovementRecord> topWastageItems;
  final Map<String, double> valuationByCategory;
}

class PaginatedMovements {
  const PaginatedMovements({
    required this.records,
    required this.hasMore,
    this.lastDocument,
  });

  final List<InventoryMovementRecord> records;
  final bool hasMore;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
}
