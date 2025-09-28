import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;

  TableGroup(this.tableName, this.items, this.groupTime);
}



