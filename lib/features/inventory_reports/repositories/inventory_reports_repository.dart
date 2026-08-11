import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:smartKitchen/core/firestore/firestore_paths.dart';
import 'package:smartKitchen/features/activity_log/services/activity_log_service.dart';
import 'package:smartKitchen/features/inventory_reports/models/inventory_models.dart';
import 'package:smartKitchen/features/inventory_reports/utils/inventory_date_utils.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_cache_service.dart';
import 'package:smartKitchen/features/menu_setup/services/menu_revision.dart';
import 'package:smartKitchen/features/menu_setup/utils/menu_sort_utils.dart';
import 'package:smartKitchen/features/ordering/utils/menu_item_variants.dart';
import 'package:smartKitchen/features/settings/utils/export_date_range.dart';

class InventoryReportsRepository {
  static const _movementPageSize = 50;
  static const _transactionBatchSize = 200;

  Future<List<InventoryCatalogItem>> loadCatalog() async {
    final overlay = await _loadInventoryOverlaySafe();
    final fromCache = await _loadCatalogFromMenuCache(overlay);
    if (fromCache.isNotEmpty) return fromCache;
    return _loadCatalogFromFirestore(overlay);
  }

  Future<Map<String, Map<String, dynamic>>> _loadInventoryOverlaySafe() async {
    try {
      return await _loadInventoryOverlay();
    } catch (_) {
      // Quantity inventory may not exist yet; menu catalog must still load.
      return {};
    }
  }

  Future<List<InventoryCatalogItem>> _loadCatalogFromMenuCache(
    Map<String, Map<String, dynamic>> overlay,
  ) async {
    try {
      final MenuCacheService cache;
      if (Get.isRegistered<MenuCacheService>()) {
        cache = Get.find<MenuCacheService>();
      } else {
        cache = Get.put(MenuCacheService(), permanent: true);
      }

      var source = await cache.loadFromCacheOnly();
      if (source.isEmpty) {
        source = await cache.ensureLoaded();
      }
      if (source.isEmpty) return const [];

      final catalog = <InventoryCatalogItem>[];
      final seen = <String>{};

      for (final raw in source) {
        final categoryId = raw['categoryId']?.toString() ?? '';
        final itemId = raw['itemId']?.toString() ?? '';
        if (categoryId.isEmpty || itemId.isEmpty) continue;

        final categoryName =
            raw['category']?.toString() ??
            raw['categoryName']?.toString() ??
            'Menu';
        final key = '$categoryId|$itemId';
        if (!seen.add(key)) continue;

        final overlayData = overlay[key];
        catalog.add(
          InventoryCatalogItem(
            menuItemKey: key,
            categoryId: categoryId,
            categoryName: categoryName,
            itemId: itemId,
            name: MenuItemVariants.displayName(raw),
            unit: overlayData?['unit']?.toString() ?? 'pcs',
            sellingPrice: _itemSellingPrice(raw),
            costPerUnit: _asDouble(overlayData?['costPerUnit']),
            currentStock: _asDouble(overlayData?['currentStock']),
            minimumStock: _asDouble(overlayData?['minimumStock']),
          ),
        );
      }

      catalog.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return catalog;
    } catch (_) {
      return const [];
    }
  }

  Future<List<InventoryCatalogItem>> _loadCatalogFromFirestore(
    Map<String, Map<String, dynamic>> overlay,
  ) async {
    final catSnap = await FirestorePaths.scoped('menus').get();
    final categories = sortMenuDocs(
      catSnap.docs.where((doc) => !MenuRevision.isMetaDoc(doc.id)).toList(),
    );

    final catalog = <InventoryCatalogItem>[];

    for (final catDoc in categories) {
      final categoryId = catDoc.id;
      final categoryName = catDoc.data()['name']?.toString() ?? 'Menu';
      final itemSnap = await FirestorePaths
          .scopedSubCollection('menus', categoryId, 'items')
          .get();

      final docById = {for (final doc in itemSnap.docs) doc.id: doc};
      final rawItems = sortMenuDocs(itemSnap.docs).map((doc) {
        final data = doc.data();
        return {
          ...data,
          'categoryId': categoryId,
          'itemId': doc.id,
          'category': categoryName,
        };
      }).toList();

      final normalized = MenuItemVariants.normalizeCategoryItems(
        rawItems,
        categoryName,
      );

      for (final item in normalized) {
        final itemId = item['itemId']?.toString() ?? '';
        final key = '$categoryId|$itemId';
        final overlayData = overlay[key];
        final price = _itemSellingPrice(item);

        catalog.add(
          InventoryCatalogItem(
            menuItemKey: key,
            categoryId: categoryId,
            categoryName: categoryName,
            itemId: itemId,
            name: MenuItemVariants.displayName(item),
            unit: overlayData?['unit']?.toString() ?? 'pcs',
            sellingPrice: price,
            costPerUnit: _asDouble(overlayData?['costPerUnit']),
            currentStock: _asDouble(overlayData?['currentStock']),
            minimumStock: _asDouble(overlayData?['minimumStock']),
          ),
        );

        if (MenuItemVariants.hasVariants(item)) {
          for (final variant in MenuItemVariants.variantsOf(item)) {
            final vCatId =
                variant['categoryId']?.toString() ?? categoryId;
            final vItemId = variant['itemId']?.toString();
            if (vItemId == null) continue;
            final vKey = '$vCatId|$vItemId';
            if (catalog.any((c) => c.menuItemKey == vKey)) continue;
            final vDoc = docById[vItemId];
            final vOverlay = overlay[vKey];
            catalog.add(
              InventoryCatalogItem(
                menuItemKey: vKey,
                categoryId: vCatId,
                categoryName: categoryName,
                itemId: vItemId,
                name: MenuItemVariants.displayName(variant),
                unit: vOverlay?['unit']?.toString() ?? 'pcs',
                sellingPrice:
                    _asDouble(variant['price'] ?? vDoc?.data()['price']),
                costPerUnit: _asDouble(vOverlay?['costPerUnit']),
                currentStock: _asDouble(vOverlay?['currentStock']),
                minimumStock: _asDouble(vOverlay?['minimumStock']),
              ),
            );
          }
        }
      }
    }

    catalog.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return catalog;
  }

  Future<Map<String, Map<String, dynamic>>> _loadInventoryOverlay() async {
    final snap = await FirestorePaths.scoped('inventory_items').get();
    final map = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final key = data['menuItemKey']?.toString() ?? doc.id;
      map[key] = data;
    }
    return map;
  }

  Future<InventoryDashboardData> loadDashboard(ExportDateRange range) async {
    final catalog = await loadCatalog();
    final movements = await _loadMovementsInRange(range);
    final sales = await _loadSyntheticSales(range);
    final allMovements = [...movements, ...sales];

    var lowStock = 0;
    var outOfStock = 0;
    var totalValue = 0.0;
    final valuationByCategory = <String, double>{};

    for (final item in catalog) {
      final status = inventoryStockStatus(
        currentStock: item.currentStock,
        minimumStock: item.minimumStock,
      );
      if (status == InventoryStockStatus.lowStock) lowStock++;
      if (status == InventoryStockStatus.outOfStock) outOfStock++;
      final value = item.currentStock * item.costPerUnit;
      totalValue += value;
      valuationByCategory[item.categoryName] =
          (valuationByCategory[item.categoryName] ?? 0) + value;
    }

    var stockIn = 0.0;
    var stockOut = 0.0;
    var wastageQty = 0.0;
    var wastageCost = 0.0;
    final wastageRecords = <InventoryMovementRecord>[];

    for (final m in allMovements) {
      switch (m.movementType) {
        case InventoryMovementType.stockIn:
        case InventoryMovementType.returnItem:
          stockIn += m.quantity.abs();
        case InventoryMovementType.sale:
          stockOut += m.quantity.abs();
        case InventoryMovementType.wastage:
          wastageQty += m.quantity.abs();
          wastageCost += m.totalCost > 0
              ? m.totalCost
              : m.quantity.abs() * _costForKey(catalog, m.menuItemKey);
          wastageRecords.add(m);
        case InventoryMovementType.adjustment:
          if (m.quantity < 0) {
            stockOut += m.quantity.abs();
          } else {
            stockIn += m.quantity;
          }
      }
    }

    final consumption = await loadItemConsumption(
      range,
      sort: ConsumptionSortOption.highestConsumption,
    );

    wastageRecords.sort((a, b) => b.quantity.compareTo(a.quantity));

    return InventoryDashboardData(
      range: range,
      totalItems: catalog.length,
      lowStockItems: lowStock,
      outOfStockItems: outOfStock,
      totalInventoryValue: totalValue,
      stockInTotal: stockIn,
      stockOutTotal: stockOut,
      wastageTotal: wastageQty,
      wastageCost: wastageCost,
      topConsumedItems: consumption.take(5).toList(),
      topWastageItems: wastageRecords.take(5).toList(),
      valuationByCategory: valuationByCategory,
    );
  }

  Future<List<CurrentStockRow>> loadCurrentStock({
    required ExportDateRange range,
    String? search,
    String? category,
    InventoryStockStatus? statusFilter,
  }) async {
    final catalog = await loadCatalog();
    final movements = await _loadMovementsInRange(range);
    final sales = await _loadSyntheticSales(range);
    final periodTotals = _aggregatePeriodTotals([...movements, ...sales]);

    final rows = <CurrentStockRow>[];
    for (final item in catalog) {
      final totals = periodTotals[item.menuItemKey] ?? _PeriodTotals.empty();
      final opening = item.currentStock -
          totals.stockIn +
          totals.stockUsed +
          totals.wastage -
          totals.adjustment;
      final rowStatus = inventoryStockStatus(
        currentStock: item.currentStock,
        minimumStock: item.minimumStock,
      );

      rows.add(
        CurrentStockRow(
          menuItemKey: item.menuItemKey,
          itemName: item.name,
          category: item.categoryName,
          openingStock: opening < 0 ? 0 : opening,
          stockIn: totals.stockIn,
          stockUsed: totals.stockUsed,
          wastage: totals.wastage,
          adjustment: totals.adjustment,
          currentStock: item.currentStock,
          minimumStock: item.minimumStock,
          status: rowStatus,
          unit: item.unit,
        ),
      );
    }

    return _filterCurrentStockRows(
      rows,
      search: search,
      category: category,
      statusFilter: statusFilter,
    );
  }

  Future<PaginatedMovements> loadStockMovements({
    required ExportDateRange range,
    String? itemKey,
    String? category,
    InventoryMovementType? movementType,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = _movementPageSize,
    bool includeSyntheticSales = true,
  }) async {
    Query<Map<String, dynamic>> query = FirestorePaths
        .scoped('inventory_movements')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.from),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(range.to),
        )
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    var records = snap.docs.map(InventoryMovementRecord.fromDoc).toList();

    if (includeSyntheticSales &&
        startAfter == null &&
        (movementType == null ||
            movementType == InventoryMovementType.sale)) {
      final sales = await _loadSyntheticSales(range);
      records = [...records, ...sales]
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
    }

    records = _filterMovements(
      records,
      itemKey: itemKey,
      category: category,
      movementType: movementType,
    );

    if (records.length > pageSize) {
      records = records.take(pageSize).toList();
    }

    return PaginatedMovements(
      records: records,
      hasMore: snap.docs.length >= pageSize,
      lastDocument: snap.docs.isEmpty ? null : snap.docs.last,
    );
  }

  Future<List<InventoryMovementRecord>> loadStockInReport({
    required ExportDateRange range,
    String? search,
    String? category,
    String? supplier,
  }) async {
    final movements = await _loadMovementsInRange(
      range,
      types: {InventoryMovementType.stockIn, InventoryMovementType.returnItem},
    );

    return movements.where((m) {
      if (category != null &&
          category.isNotEmpty &&
          m.categoryName != category) {
        return false;
      }
      if (supplier != null &&
          supplier.isNotEmpty &&
          (m.supplier ?? '').toLowerCase() != supplier.toLowerCase()) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!m.itemName.toLowerCase().contains(q) &&
            !(m.invoiceNumber ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<List<InventoryMovementRecord>> loadWastageReport({
    required ExportDateRange range,
    String? search,
    String? category,
  }) async {
    final catalog = await loadCatalog();
    final movements = await _loadMovementsInRange(
      range,
      types: {InventoryMovementType.wastage},
    );

    return movements.where((m) {
      if (category != null &&
          category.isNotEmpty &&
          m.categoryName != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!m.itemName.toLowerCase().contains(q) &&
            !(m.reason ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).map((m) {
      if (m.totalCost > 0) return m;
      final cost = _costForKey(catalog, m.menuItemKey);
      return InventoryMovementRecord(
        id: m.id,
        menuItemKey: m.menuItemKey,
        itemName: m.itemName,
        categoryName: m.categoryName,
        movementType: m.movementType,
        quantity: m.quantity,
        previousStock: m.previousStock,
        currentStock: m.currentStock,
        reason: m.reason,
        supplier: m.supplier,
        purchasePrice: cost,
        unit: m.unit,
        invoiceNumber: m.invoiceNumber,
        addedBy: m.addedBy,
        createdAt: m.createdAt,
        isSynthetic: m.isSynthetic,
        wastageReason: m.wastageReason,
      );
    }).toList();
  }

  Future<List<LowStockRow>> loadLowStockReport({
    String? search,
    String? category,
    InventoryStockStatus? statusFilter,
  }) async {
    final catalog = await loadCatalog();
    final rows = <LowStockRow>[];

    for (final item in catalog) {
      final status = inventoryStockStatus(
        currentStock: item.currentStock,
        minimumStock: item.minimumStock,
      );
      if (status == InventoryStockStatus.inStock) continue;

      rows.add(
        LowStockRow(
          itemName: item.name,
          category: item.categoryName,
          currentStock: item.currentStock,
          minimumStock: item.minimumStock,
          unit: item.unit,
          reorderQuantity: inventoryReorderQuantity(
            currentStock: item.currentStock,
            minimumStock: item.minimumStock,
          ),
          status: status,
        ),
      );
    }

    return rows.where((row) {
      if (statusFilter != null && row.status != statusFilter) return false;
      if (category != null &&
          category.isNotEmpty &&
          row.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!row.itemName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.currentStock.compareTo(b.currentStock));
  }

  Future<List<ValuationRow>> loadValuationReport({
    String? search,
    String? category,
  }) async {
    final catalog = await loadCatalog();
    final rows = catalog
        .map(
          (item) => ValuationRow(
            itemName: item.name,
            currentQuantity: item.currentStock,
            unit: item.unit,
            costPerUnit: item.costPerUnit,
            totalValue: item.currentStock * item.costPerUnit,
          ),
        )
        .toList();

    final nameToCategory = {
      for (final item in catalog) item.name: item.categoryName,
    };

    return rows.where((row) {
      if (category != null &&
          category.isNotEmpty &&
          nameToCategory[row.itemName] != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!row.itemName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.totalValue.compareTo(a.totalValue));
  }

  Future<List<ItemConsumptionRow>> loadItemConsumption(
    ExportDateRange range, {
    ConsumptionSortOption sort = ConsumptionSortOption.highestConsumption,
    String? search,
    String? category,
  }) async {
    final catalog = await loadCatalog();
    final catalogByName = <String, InventoryCatalogItem>{};
    for (final item in catalog) {
      catalogByName[item.name.toLowerCase()] = item;
    }

    final docs = await _fetchTransactions(range);
    final totals = <String, _ConsumptionAccumulator>{};

    for (final doc in docs) {
      final items = doc.data()['items'] as List<dynamic>? ?? const [];
      for (final raw in items) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final qty = _asDouble(raw['qty']);
        if (qty <= 0) continue;
        final price = _asDouble(raw['price']);
        final key = name.toLowerCase();
        totals.putIfAbsent(key, () => _ConsumptionAccumulator(name: name));
        totals[key]!
          ..quantity += qty
          ..revenue += qty * price;
      }
    }

    final rows = totals.values.map((acc) {
      final catalogItem = catalogByName[acc.name.toLowerCase()];
      final costPerUnit = catalogItem?.costPerUnit ?? 0;
      final estimatedCost = acc.quantity * costPerUnit;
      return ItemConsumptionRow(
        itemName: acc.name,
        category: catalogItem?.categoryName ?? '—',
        quantityConsumed: acc.quantity,
        revenue: acc.revenue,
        estimatedCost: estimatedCost,
        grossProfit: acc.revenue - estimatedCost,
      );
    }).toList();

    final filtered = rows.where((row) {
      if (category != null &&
          category.isNotEmpty &&
          row.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!row.itemName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (sort) {
        case ConsumptionSortOption.highestConsumption:
          return b.quantityConsumed.compareTo(a.quantityConsumed);
        case ConsumptionSortOption.lowestConsumption:
          return a.quantityConsumed.compareTo(b.quantityConsumed);
        case ConsumptionSortOption.highestRevenue:
          return b.revenue.compareTo(a.revenue);
        case ConsumptionSortOption.highestProfit:
          return b.grossProfit.compareTo(a.grossProfit);
      }
    });

    return filtered;
  }

  Future<List<String>> loadCategories() async {
    final catalog = await loadCatalog();
    final categories = catalog.map((c) => c.categoryName).toSet().toList()
      ..sort();
    return categories;
  }

  /// Adds quantity stock (Stock In) without changing menu [inStock] availability.
  Future<double> addStockIn({
    required InventoryCatalogItem item,
    required double quantity,
    required DateTime stockDate,
    String unit = 'pcs',
    double? purchasePrice,
    double? minimumStock,
    double? costPerUnit,
    String? supplier,
    String? invoiceNumber,
    String? reason,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0.');
    }

    final actor = ActivityLogService.currentActor();
    final addedBy = actor?.userName ?? 'Unknown';
    final previousStock = item.currentStock;
    final newStock = previousStock + quantity;
    final effectiveCost = costPerUnit ?? purchasePrice ?? item.costPerUnit;
    final effectiveMin =
        minimumStock ?? (item.minimumStock > 0 ? item.minimumStock : 0);
    final effectiveUnit = unit.trim().isEmpty ? item.unit : unit.trim();

    final itemRef = await _inventoryItemRef(item.menuItemKey);
    final movementRef = FirestorePaths.scoped('inventory_movements').doc();

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      itemRef,
      {
        'menuItemKey': item.menuItemKey,
        'itemId': item.itemId,
        'categoryId': item.categoryId,
        'itemName': item.name,
        'categoryName': item.categoryName,
        'currentStock': newStock,
        'minimumStock': effectiveMin,
        'unit': effectiveUnit,
        'costPerUnit': effectiveCost,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(movementRef, {
      'menuItemKey': item.menuItemKey,
      'itemName': item.name,
      'categoryName': item.categoryName,
      'movementType': InventoryMovementType.stockIn.firestoreValue,
      'quantity': quantity,
      'previousStock': previousStock,
      'currentStock': newStock,
      'reason': (reason ?? '').trim().isEmpty ? 'Stock In' : reason!.trim(),
      'supplier': supplier?.trim() ?? '',
      'purchasePrice': purchasePrice ?? effectiveCost,
      'unit': effectiveUnit,
      'invoiceNumber': invoiceNumber?.trim() ?? '',
      'addedBy': addedBy,
      'addedByUserId': actor?.userId,
      'createdAt': Timestamp.fromDate(stockDate),
    });

    await batch.commit();
    return newStock;
  }

  Future<DocumentReference<Map<String, dynamic>>> _inventoryItemRef(
    String menuItemKey,
  ) async {
    final existing = await FirestorePaths.scoped('inventory_items')
        .where('menuItemKey', isEqualTo: menuItemKey)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.reference;
    }

    // Stable doc id so re-adds merge cleanly without duplicate masters.
    final docId = menuItemKey.replaceAll('|', '__');
    return FirestorePaths.scoped('inventory_items').doc(docId);
  }

  Future<List<InventoryMovementRecord>> _loadMovementsInRange(
    ExportDateRange range, {
    Set<InventoryMovementType>? types,
  }) async {
    final records = <InventoryMovementRecord>[];
    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      Query<Map<String, dynamic>> query = FirestorePaths
          .scoped('inventory_movements')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.from),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(range.to),
          )
          .orderBy('createdAt', descending: false)
          .limit(_movementPageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final record = InventoryMovementRecord.fromDoc(doc);
        if (types == null || types.contains(record.movementType)) {
          records.add(record);
        }
      }

      if (snap.docs.length < _movementPageSize) break;
      lastDoc = snap.docs.last;
    }

    return records;
  }

  Future<List<InventoryMovementRecord>> _loadSyntheticSales(
    ExportDateRange range,
  ) async {
    final catalog = await loadCatalog();
    final nameToItem = <String, InventoryCatalogItem>{
      for (final item in catalog) item.name.toLowerCase(): item,
    };

    final docs = await _fetchTransactions(range);
    final records = <InventoryMovementRecord>[];

    for (final doc in docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final addedBy = data['billedBy']?.toString() ??
          data['userName']?.toString() ??
          'Billing';
      final items = data['items'] as List<dynamic>? ?? const [];

      for (var i = 0; i < items.length; i++) {
        final raw = items[i];
        if (raw is! Map) continue;
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final qty = _asDouble(raw['qty']);
        if (qty <= 0) continue;
        final catalogItem = nameToItem[name.toLowerCase()];

        records.add(
          InventoryMovementRecord(
            id: '${doc.id}_sale_$i',
            menuItemKey: catalogItem?.menuItemKey ?? '',
            itemName: name,
            categoryName: catalogItem?.categoryName ?? '—',
            movementType: InventoryMovementType.sale,
            quantity: qty,
            previousStock: 0,
            currentStock: 0,
            reason: 'Sale from transaction',
            addedBy: addedBy,
            createdAt: createdAt,
            isSynthetic: true,
          ),
        );
      }
    }

    return records;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchTransactions(
    ExportDateRange range,
  ) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      Query<Map<String, dynamic>> query = FirestorePaths
          .scoped('transactions')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.from),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(range.to),
          )
          .orderBy('createdAt', descending: false)
          .limit(_transactionBatchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      docs.addAll(snap.docs);
      if (snap.docs.length < _transactionBatchSize) break;
      lastDoc = snap.docs.last;
    }

    return docs;
  }

  Map<String, _PeriodTotals> _aggregatePeriodTotals(
    List<InventoryMovementRecord> movements,
  ) {
    final map = <String, _PeriodTotals>{};
    for (final m in movements) {
      if (m.menuItemKey.isEmpty) continue;
      final totals = map.putIfAbsent(m.menuItemKey, () => _PeriodTotals.empty());
      switch (m.movementType) {
        case InventoryMovementType.stockIn:
        case InventoryMovementType.returnItem:
          totals.stockIn += m.quantity.abs();
        case InventoryMovementType.sale:
          totals.stockUsed += m.quantity.abs();
        case InventoryMovementType.wastage:
          totals.wastage += m.quantity.abs();
        case InventoryMovementType.adjustment:
          totals.adjustment += m.quantity;
      }
    }
    return map;
  }

  List<CurrentStockRow> _filterCurrentStockRows(
    List<CurrentStockRow> rows, {
    String? search,
    String? category,
    InventoryStockStatus? statusFilter,
  }) {
    return rows.where((row) {
      if (statusFilter != null && row.status != statusFilter) return false;
      if (category != null &&
          category.isNotEmpty &&
          row.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!row.itemName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<InventoryMovementRecord> _filterMovements(
    List<InventoryMovementRecord> records, {
    String? itemKey,
    String? category,
    InventoryMovementType? movementType,
  }) {
    return records.where((m) {
      if (itemKey != null &&
          itemKey.isNotEmpty &&
          m.menuItemKey != itemKey) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          m.categoryName != category) {
        return false;
      }
      if (movementType != null && m.movementType != movementType) return false;
      return true;
    }).toList();
  }

  double _costForKey(List<InventoryCatalogItem> catalog, String key) {
    for (final item in catalog) {
      if (item.menuItemKey == key) return item.costPerUnit;
    }
    return 0;
  }

  double _itemSellingPrice(Map<String, dynamic> item) {
    final variants = item['variants'];
    if (variants is List && variants.isNotEmpty) {
      final first = variants.first;
      if (first is Map) return _asDouble(first['price']);
    }
    if (item.containsKey('fullPrice')) return _asDouble(item['fullPrice']);
    return _asDouble(item['price']);
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _PeriodTotals {
  double stockIn = 0;
  double stockUsed = 0;
  double wastage = 0;
  double adjustment = 0;

  static _PeriodTotals empty() => _PeriodTotals();
}

class _ConsumptionAccumulator {
  _ConsumptionAccumulator({required this.name});

  final String name;
  double quantity = 0;
  double revenue = 0;
}
