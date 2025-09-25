import 'package:flutter/material.dart';
import 'CartPage.dart';
import 'FinalCartPage.dart';
import 'MenuPage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flutter/material.dart';
import 'MenuPage.dart';

import 'package:flutter/material.dart';
import 'MenuPage.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class DragListBetweenTables extends StatefulWidget {
  @override
  State<DragListBetweenTables> createState() => _DragListBetweenTablesState();
}

class _DragListBetweenTablesState extends State<DragListBetweenTables> {
  Map<String, List<Map<String, dynamic>>> tables = {
    "Table 1": [],
    "Table 2": [],
    "Table 3": [],
    "Table 4": [],
    "Table 5": [],
    "Table 6": [],
    "Table 7": [],
    "Table 8": [],
    "Table 9": [],
    "Table 10": [],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Drag Whole Item List Between Tables")),
      body: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12.0),
        child: MasonryGridView.count(
          crossAxisCount: 2, // 2 columns
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: tables.keys.length,
          itemBuilder: (context, index) {
            final tableName = tables.keys.elementAt(index);
            final items = tables[tableName]!;

            return DragTarget<String>(
              onAccept: (sourceTable) {
                if (sourceTable != tableName) {
                  setState(() {
                    tables[tableName]!.addAll(tables[sourceTable]!);
                    tables[sourceTable]!.clear();
                  });
                }
              },
              builder: (context, candidateData, rejectedData) {
                return LongPressDraggable<String>(
                  data: tableName,
                  feedback: Material(
                    child: Container(
                      width: 160,
                      padding: EdgeInsets.all(8),
                      color: Colors.blueAccent,
                      child: Text(
                        tableName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // adjust the radius
                    ),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: items.isNotEmpty
                              ? Colors.green
                              : Colors.orange,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tableName,
                                style: TextStyle(color: Colors.white),
                              ),
                              InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MenuPage(
                                        initialItems:
                                            List<Map<String, dynamic>>.from(
                                              items,
                                            ),
                                        onConfirm: (selectedItems) {
                                          setState(() {
                                            tables[tableName]!.clear();
                                            tables[tableName]!.addAll(
                                              selectedItems,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.add_circle,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                "No items",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black38,
                                ),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onDoubleTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FinalCartPage(
                                    menuData: List<Map<String, dynamic>>.from(
                                      items,
                                    ),
                                    onConfirm: (selectedItems) {
                                      setState(() {
                                        tables[tableName]!.clear();
                                        tables[tableName]!.addAll(
                                          selectedItems,
                                        );
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: items.map((item) {
                                  final qty = item['qty'] ?? 1;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: item['name'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          TextSpan(
                                            text: " \u00D7$qty",
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
