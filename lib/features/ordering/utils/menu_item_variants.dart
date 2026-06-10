/// Groups Half/Full menu rows for display and expands them for cart/billing.
class MenuItemVariants {
  MenuItemVariants._();

  static final RegExp _halfName = RegExp(r'^(.+) \((Half)\)$', caseSensitive: false);
  static final RegExp _fullName = RegExp(r'^(.+) \((Full)\)$', caseSensitive: false);

  static bool hasVariants(Map<String, dynamic> item) =>
      item['hasVariants'] == true;

  static String displayName(Map<String, dynamic> item) =>
      item['displayName']?.toString() ?? item['name']?.toString() ?? '';

  static List<Map<String, dynamic>> variantsOf(Map<String, dynamic> item) {
    final raw = item['variants'];
    if (raw is! List) return const [];
    return raw.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }

  static int totalQty(Map<String, dynamic> item) {
    if (!hasVariants(item)) return item['qty'] as int? ?? 0;
    return variantsOf(item).fold<int>(
      0,
      (sum, v) => sum + (v['qty'] as int? ?? 0),
    );
  }

  static double totalLinePrice(Map<String, dynamic> item) {
    if (!hasVariants(item)) {
      return (item['qty'] as int? ?? 0) * ((item['price'] as num?)?.toDouble() ?? 0);
    }
    return variantsOf(item).fold<double>(
      0,
      (sum, v) =>
          sum + (v['qty'] as int? ?? 0) * ((v['price'] as num?)?.toDouble() ?? 0),
    );
  }

  static String priceLabel(Map<String, dynamic> item) {
    if (!hasVariants(item)) {
      return '₹${((item['price'] as num?) ?? 0).toStringAsFixed(0)}';
    }
    final variants = variantsOf(item);
    if (variants.length >= 2) {
      final half = variants.firstWhere(
        (v) => v['label']?.toString().toLowerCase() == 'half',
        orElse: () => variants.first,
      );
      final full = variants.firstWhere(
        (v) => v['label']?.toString().toLowerCase() == 'full',
        orElse: () => variants.last,
      );
      return '₹${(half['price'] as num).toStringAsFixed(0)} / '
          '₹${(full['price'] as num).toStringAsFixed(0)}';
    }
    return '₹${((item['price'] as num?) ?? 0).toStringAsFixed(0)}';
  }

  static List<Map<String, dynamic>> normalizeMenuList(
    List<Map<String, dynamic>> menuList,
  ) {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final item in menuList) {
      final category = item['category']?.toString() ?? '';
      byCategory.putIfAbsent(category, () => []).add(Map<String, dynamic>.from(item));
    }

    final categories = byCategory.keys.toList()
      ..sort((a, b) {
        final aOrder = _categorySortOrder(byCategory[a]!);
        final bOrder = _categorySortOrder(byCategory[b]!);
        return aOrder.compareTo(bOrder);
      });

    final normalized = <Map<String, dynamic>>[];
    for (final category in categories) {
      final items = List<Map<String, dynamic>>.from(byCategory[category]!)
        ..sort(
          (a, b) =>
              _itemSortOrder(a).compareTo(_itemSortOrder(b)),
        );
      normalized.addAll(_normalizeCategoryItems(items, category));
    }
    return normalized;
  }

  /// Normalizes items within a single category (merges Half/Full pairs).
  static List<Map<String, dynamic>> normalizeCategoryItems(
    List<Map<String, dynamic>> items,
    String category,
  ) => _normalizeCategoryItems(items, category);

  static int _categorySortOrder(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final order = item['categorySortOrder'] as int?;
      if (order != null) return order;
    }
    return 9999;
  }

  static int _itemSortOrder(Map<String, dynamic> item) =>
      item['itemSortOrder'] as int? ?? 9999;

  static List<Map<String, dynamic>> _normalizeCategoryItems(
    List<Map<String, dynamic>> items,
    String category,
  ) {
    final result = <Map<String, dynamic>>[];
    final mergedBases = <String>{};

    for (final item in items) {
      if (item['variants'] is List && (item['variants'] as List).length >= 2) {
        result.add(_fromExplicitVariants(item, category));
        continue;
      }

      if (item.containsKey('halfPrice') && item.containsKey('fullPrice')) {
        result.add(_fromHalfFullPrices(item, category));
        continue;
      }

      final name = item['name']?.toString() ?? '';
      final halfMatch = _halfName.firstMatch(name);
      if (halfMatch != null) {
        final baseName = halfMatch.group(1)!.trim();
        if (mergedBases.contains(baseName)) continue;

        final fullItem = _findPairedItem(items, baseName, isHalf: false);
        if (fullItem != null) {
          mergedBases.add(baseName);
          result.add(
            _buildVariantItem(
              category: category,
              baseName: baseName,
              halfSource: item,
              fullSource: fullItem,
              halfPrice: (item['price'] as num).toDouble(),
              fullPrice: (fullItem['price'] as num).toDouble(),
            ),
          );
          continue;
        }
      }

      final fullMatch = _fullName.firstMatch(name);
      if (fullMatch != null) {
        final baseName = fullMatch.group(1)!.trim();
        if (mergedBases.contains(baseName)) continue;
      }

      result.add(_singleItem(item, category));
    }

    return result;
  }

  static Map<String, dynamic>? _findPairedItem(
    List<Map<String, dynamic>> items,
    String baseName, {
    required bool isHalf,
  }) {
    final target = isHalf ? '$baseName (Half)' : '$baseName (Full)';
    for (final item in items) {
      if (item['name']?.toString().toLowerCase() == target.toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  static Map<String, dynamic> _singleItem(
    Map<String, dynamic> item,
    String category,
  ) {
    return {
      ...item,
      'category': category,
      'hasVariants': false,
      'qty': 0,
    };
  }

  static Map<String, dynamic> _fromHalfFullPrices(
    Map<String, dynamic> item,
    String category,
  ) {
    final baseName = item['name']?.toString() ?? '';
    final halfPrice = (item['halfPrice'] as num).toDouble();
    final fullPrice = (item['fullPrice'] as num).toDouble();

    return _buildVariantItem(
      category: category,
      baseName: baseName,
      halfSource: item,
      fullSource: item,
      halfPrice: halfPrice,
      fullPrice: fullPrice,
    );
  }

  static Map<String, dynamic> _fromExplicitVariants(
    Map<String, dynamic> item,
    String category,
  ) {
    final baseName = item['name']?.toString() ?? '';
    final variants = (item['variants'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .map(
          (v) => {
            ...v,
            'name': v['name'] ?? '$baseName (${v['label']})',
            'qty': 0,
          },
        )
        .toList();

    final withIds = variants
        .map(
          (v) => {
            ...v,
            if (v['categoryId'] == null && item['categoryId'] != null)
              'categoryId': item['categoryId'],
            if (v['itemId'] == null && item['itemId'] != null)
              'itemId': item['itemId'],
          },
        )
        .toList();

    return {
      ...item,
      'category': category,
      'displayName': baseName,
      'name': baseName,
      'hasVariants': true,
      'variants': withIds,
      'price': (withIds.first['price'] as num?) ?? 0,
      'qty': 0,
    };
  }

  static Map<String, dynamic> _buildVariantItem({
    required String category,
    required String baseName,
    required Map<String, dynamic> halfSource,
    required Map<String, dynamic> fullSource,
    required double halfPrice,
    required double fullPrice,
  }) {
    return {
      'category': category,
      'categoryId': halfSource['categoryId'] ?? fullSource['categoryId'],
      'itemId': halfSource['itemId'] ?? fullSource['itemId'],
      if (halfSource['categorySortOrder'] != null)
        'categorySortOrder': halfSource['categorySortOrder'],
      if (halfSource['itemSortOrder'] != null)
        'itemSortOrder': halfSource['itemSortOrder'],
      'displayName': baseName,
      'name': baseName,
      'hasVariants': true,
      'halfPrice': halfPrice,
      'fullPrice': fullPrice,
      'price': halfPrice,
      'qty': 0,
      'inStock':
          halfSource['inStock'] != false && fullSource['inStock'] != false,
      'variants': [
        _variantLine('Half', halfPrice, halfSource, baseName),
        _variantLine('Full', fullPrice, fullSource, baseName),
      ],
    };
  }

  static Map<String, dynamic> _variantLine(
    String label,
    double price,
    Map<String, dynamic> source,
    String baseName,
  ) {
    return {
      'label': label,
      'name': '$baseName ($label)',
      'price': price,
      'qty': 0,
      if (source['itemId'] != null) 'itemId': source['itemId'],
      if (source['categoryId'] != null) 'categoryId': source['categoryId'],
    };
  }

  static List<Map<String, dynamic>> expandToCartLines(
    Map<String, dynamic> item,
  ) {
    if (!hasVariants(item)) {
      if ((item['qty'] as int? ?? 0) > 0) {
        return [Map<String, dynamic>.from(item)];
      }
      return const [];
    }

    final lines = <Map<String, dynamic>>[];
    for (final variant in variantsOf(item)) {
      final qty = variant['qty'] as int? ?? 0;
      if (qty <= 0) continue;
      lines.add({
        'name': variant['name'],
        'price': variant['price'],
        'qty': qty,
        'category': item['category'],
        'categoryId': variant['categoryId'] ?? item['categoryId'],
        if (variant['itemId'] != null) 'itemId': variant['itemId'],
        if (item['remarks'] != null) 'remarks': item['remarks'],
      });
    }
    return lines;
  }

  static void syncVariantQtyFromCart(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> cartItems,
  ) {
    if (!hasVariants(item)) {
      Map<String, dynamic>? existing;
      for (final e in cartItems) {
        if (e['name'] == item['name']) {
          existing = e;
          break;
        }
      }
      if (existing != null) {
        item['qty'] = existing['qty'];
        item['remarks'] = existing['remarks'] ?? '';
      } else {
        item['qty'] = 0;
        item['remarks'] = '';
      }
      return;
    }

    final variants = item['variants'] as List? ?? [];
    for (final raw in variants) {
      final variant = raw as Map<String, dynamic>;
      Map<String, dynamic>? existing;
      for (final e in cartItems) {
        if (e['name'] == variant['name']) {
          existing = e;
          break;
        }
      }
      variant['qty'] = existing != null ? existing['qty'] : 0;
      final remark = existing?['remarks']?.toString() ?? '';
      if (remark.isNotEmpty) item['remarks'] = remark;
    }
  }

  static void applyOrderToItem(
    Map<String, dynamic> item,
    String itemName,
    int quantity, {
    String remarks = '',
  }) {
    if (!hasVariants(item)) {
      if (item['name'] == itemName) {
        item['qty'] = (item['qty'] as int? ?? 0) + quantity;
        if (remarks.isNotEmpty) item['remarks'] = remarks;
      }
      return;
    }

    final variants = item['variants'] as List? ?? [];
    for (final raw in variants) {
      final variant = raw as Map<String, dynamic>;
      if (variant['name'] == itemName) {
        variant['qty'] = (variant['qty'] as int? ?? 0) + quantity;
        if (remarks.isNotEmpty) item['remarks'] = remarks;
      }
    }
  }
}
