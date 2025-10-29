import 'package:demo/CartPageForTakeAway.dart';
import 'package:flutter/material.dart';
import 'dart:math'; // ⬅️ add this at the top
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'CartPage.dart';

import 'package:flutter/material.dart';

import 'MyWidgets/EditableTextField.dart';
import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

class MenuPage extends StatefulWidget {
  final void Function(
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
    String tableName,
  )
  onConfirm;
  final List<Map<String, dynamic>> menuList; // Passed from previous page
  final List<Map<String, dynamic>> initialItems;
  final String tableName;
  final bool tableNameEditable;
  final bool showBilling;

  const MenuPage({
    required this.onConfirm,
    required this.menuList,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    this.initialItems = const [],
    Key? key,
  }) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late Map<String, List<Map<String, dynamic>>> menuData;
  late TextEditingController tableNameController;

  ///Serach
  TextEditingController searchController = TextEditingController();
  bool _showSearch = false;
  String searchQuery = '';
  bool isNameEdit = false;
  // Multiple category selection
  Set<String> selectedCategories = {};
  bool showAllCategories = true; // Track if "All" is selected

  @override
  void initState() {
    super.initState();
    tableNameController = TextEditingController(text: widget.tableName);
    // Group menuList by category and initialize qty = 0
    menuData = {};

    for (var item in widget.menuList) {
      final category = item['category'] as String;
      menuData[category] ??= [];
      menuData[category]!.add({...item, 'qty': 0});
    }

    // Pre-fill quantities from initialItems if any
    for (var category in menuData.keys) {
      for (var item in menuData[category]!) {
        final existingItem = widget.initialItems.firstWhere(
          (e) => e['name'] == item['name'],
          orElse: () => {},
        );
        if (existingItem.isNotEmpty) {
          item['qty'] = existingItem['qty'];
        }
      }
    }

    _loadSelectedCategories();
  }

  void incrementQty(String category, int index) {
    setState(() {
      menuData[category]![index]['qty']++;
    });
  }

  void decrementQty(String category, int index) {
    setState(() {
      if (menuData[category]![index]['qty'] > 0) {
        menuData[category]![index]['qty']--;
      }
    });
  }

  int get totalItems {
    int total = 0;
    menuData.forEach((category, items) {
      for (var item in items) total += item['qty'] as int;
    });
    return total;
  }

  double get totalPrice {
    double total = 0.0;
    menuData.forEach((category, items) {
      for (var item in items) {
        total += (item['qty'] as int) * (item['price']);
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final categories = menuData.keys.toList();

    return DefaultTabController(
      length: showAllCategories ? categories.length : selectedCategories.length,
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search menu...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.black54),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontFamily: fontMulishRegular,
                  ),
                )
              : Row(
                  children: [
                    // Text("Menu - ",style: TextStyle(
                    //   fontSize: 16,
                    //   fontFamily: fontMulishBold,
                    // ),),
                    (widget.tableName.contains("Table") ||
                            !widget.tableNameEditable)
                        ? Text(
                            widget.tableName,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: fontMulishBold,
                            ),
                          )
                        : EditableTextField(
                            controller: tableNameController,
                            onEditingChanged: (value) {
                              setState(() {
                                isNameEdit = value;
                              });
                            },
                          ),
                  ],
                ),

          actions: [
            if (!isNameEdit)
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  if (_showSearch) {
                    searchQuery = '';
                    searchController.clear();
                  } else {}
                  _showSearch = !_showSearch;

                  setState(() {});
                },
              ),

            // Filter button with badge showing count
            if (!isNameEdit)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => _showCategoryFilterDialog(context),
                    tooltip: "Filter by Category",
                  ),
                  if (!showAllCategories && selectedCategories.isNotEmpty)
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
                            '${selectedCategories.length}',
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

          bottom: !_showSearch
              ? TabBar(
                  isScrollable: true,
                  tabs: showAllCategories
                      ? categories.map((c) => Tab(text: c)).toList()
                      : selectedCategories.map((c) => Tab(text: c)).toList(),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: _showSearch
                  ? _buildGlobalSearchList()
                  : showAllCategories
                  ? TabBarView(
                      children: categories.map((category) {
                        final items = menuData[category]!;

                        return ListView.builder(
                          itemCount: items.length,
                          padding: EdgeInsets.only(top: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final qty = item['qty'] as int;

                            return InkWell(
                              onTap: () {
                                incrementQty(category, index);
                              },
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 16,
                                    ),
                                    title: Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: text_color,
                                        fontFamily: fontMulishSemiBold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        children: [
                                          SizedBox(height: 6),
                                          Text(
                                            "₹${item['price'].toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishRegular,
                                            ),
                                          ),

                                          SizedBox(width: 16),

                                          if (item['qty'] > 0)
                                            Text(
                                              "\u00D7${item['qty']}",
                                              style: TextStyle(
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
                                              setState(() {
                                                item['qty'] = 1;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.black87,
                                                  width: 0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () => decrementQty(
                                                  category,
                                                  index,
                                                ),
                                              ),
                                              Text(
                                                "$qty",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: text_color,
                                                  fontFamily:
                                                      fontMulishSemiBold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () => incrementQty(
                                                  category,
                                                  index,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),

                                  Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    height: 0.5,
                                    color: Colors.grey.shade300,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    )
                  : TabBarView(
                      children: selectedCategories.map((category) {
                        final items = menuData[category];

                        return ListView.builder(
                          itemCount: items?.length,
                          padding: EdgeInsets.only(top: 8),
                          itemBuilder: (context, index) {
                            final item = items?[index];
                            final qty = item?['qty'];

                            return InkWell(
                              onTap: () {
                                incrementQty(category, index);
                              },
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 16,
                                    ),
                                    title: Text(
                                      item?['name'] ?? "",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: text_color,
                                        fontFamily: fontMulishSemiBold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        children: [
                                          SizedBox(height: 6),
                                          Text(
                                            "₹${item?['price'].toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: secondary_text_color,
                                              fontFamily: fontMulishRegular,
                                            ),
                                          ),

                                          SizedBox(width: 16),

                                          if ((item?['qty'] ?? 0) > 0)
                                            Text(
                                              "\u00D7${item?['qty']}",
                                              style: TextStyle(
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
                                              setState(() {
                                                item?['qty'] = 1;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.black87,
                                                  width: 0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () => decrementQty(
                                                  category,
                                                  index,
                                                ),
                                              ),
                                              Text(
                                                "$qty",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: text_color,
                                                  fontFamily:
                                                      fontMulishSemiBold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () => incrementQty(
                                                  category,
                                                  index,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),

                                  Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    height: 0.5,
                                    color: Colors.grey.shade300,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),
            if (totalItems > 0)
              InkWell(
                onTap: () {
                  final selectedItems = <Map<String, dynamic>>[];

                  menuData.forEach((category, items) {
                    selectedItems.addAll(
                      items.where((item) => item['qty'] > 0),
                    );
                  });

                  // Send selected items to cart or callback

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartPage(
                        tableName: tableNameController.text,
                        tableNameEditable: widget.tableNameEditable,
                        menuData: selectedItems,
                        onConfirm: widget.onConfirm,
                        showBilling: widget.showBilling,
                      ),
                    ),
                  ).then((onValue) {
                    if (onValue != null) {
                      List<Map<String, dynamic>> changedItems = onValue;

                      // Pre-fill quantities from initialItems if any
                      for (var category in menuData.keys) {
                        for (var item in menuData[category]!) {
                          final existingItem = changedItems.firstWhere(
                            (e) => e['name'] == item['name'],
                            orElse: () => {},
                          );
                          if (existingItem.isNotEmpty) {
                            item['qty'] = existingItem['qty'];
                          }
                        }
                      }

                      setState(() {});
                    }
                  });
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

                      Icon(Icons.arrow_forward_ios, color: Colors.white),

                      // ElevatedButton(
                      //   onPressed: () {
                      //     final selectedItems = <Map<String, dynamic>>[];
                      //     menuData.forEach((category, items) {
                      //       selectedItems.addAll(
                      //         items.where((item) => item['qty'] > 0),
                      //       );
                      //     });
                      //
                      //     // Send selected items to cart or callback
                      //
                      //
                      //     if(widget.tableName == "Take Away"){
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //           builder: (_) => CartPageForTakeAway(
                      //             tableName: widget.tableName,
                      //             menuData: selectedItems,
                      //             onConfirm: widget.onConfirm,
                      //           ),
                      //         ),
                      //       );
                      //     }else{
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //           builder: (_) => CartPage(
                      //             tableName: widget.tableName,
                      //             menuData: selectedItems,
                      //             onConfirm: widget.onConfirm,
                      //           ),
                      //         ),
                      //       );
                      //     }
                      //
                      //
                      //   },
                      //   child: const Text("View Cart"),
                      // ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final categories = menuData.keys.toList();

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    // "All" checkbox
                    CheckboxListTile(
                      title: const Text(
                        "All Categories",
                        style: TextStyle(
                          fontFamily: fontMulishSemiBold,
                          fontSize: 15,
                        ),
                      ),
                      value: showAllCategories,
                      activeColor: Colors.green,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          showAllCategories = value ?? true;
                          if (showAllCategories) {
                            selectedCategories.clear();
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const Divider(),
                    // Individual category checkboxes
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final categoryName = category;
                          final isSelected = selectedCategories.contains(
                            categoryName,
                          );

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
                            enabled: !showAllCategories,
                            onChanged: showAllCategories
                                ? null
                                : (bool? value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedCategories.add(categoryName);
                                      } else {
                                        selectedCategories.remove(categoryName);
                                      }
                                    });
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
                    setDialogState(() {
                      selectedCategories.clear();
                      showAllCategories = true;
                    });

                    _saveSelectedCategories();

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
                    _saveSelectedCategories();
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
          },
        );
      },
    );
  }

  /// ✅ Save to SharedPreferences
  Future<void> _saveSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selectedCategories',
      selectedCategories.toList(),
    );

    print("_saveSelectedCategories call");
  }

  /// ✅ Load from SharedPreferences
  Future<void> _loadSelectedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedList = prefs.getStringList('selectedCategories');

    selectedCategories = storedList?.toSet() ?? {};
    if (selectedCategories.isNotEmpty) {
      showAllCategories = false;
      print("showAllCategories false");
    }

    setState(() {});
  }

  Widget _buildGlobalSearchList() {
    final allItems = <Map<String, dynamic>>[];

    final sourceCategories = showAllCategories
        ? menuData.keys
        : selectedCategories;

    for (var category in sourceCategories) {
      allItems.addAll(menuData[category]!);
    }

    final filtered = allItems.where((item) {
      final name = item['name'].toString().toLowerCase();
      return name.contains(searchQuery);
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
        setState(() {
          item['qty']++;
        });
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
                      setState(() {
                        item['qty'] = 1;
                      });
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
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          if (item['qty'] > 0) {
                            item['qty']--;
                            setState(() {});
                          }
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
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          item['qty']++;
                          setState(() {});
                        },
                      ),
                    ],
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
}
