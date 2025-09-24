import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:math'; // ⬅️ add this at the top

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

/// Cart Page
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CartPage extends StatelessWidget {
  final List<Map<String, dynamic>> menuData;
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;
  final GlobalKey _repaintKey = GlobalKey();

  CartPage({required this.menuData, required this.onConfirm});

  double get subtotal {
    double total = 0;
    for (var item in menuData) {
      total += (item['qty'] as int) * (item['price'] as double);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final tax = subtotal * 0.085;
    final tip = subtotal * 0.15;
    final total = subtotal + tax + tip;

    return Scaffold(
      appBar: AppBar(title: Text("Cart")),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey, // Key to capture this widget
              child: menuData.isEmpty
                  ? Center(child: Text("No items in cart"))
                  : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  headingRowColor: MaterialStateColor.resolveWith(
                        (states) => Colors.orange.shade100,
                  ),
                  columns: const [
                    DataColumn(label: Text("Item")),
                    DataColumn(label: Text("Qty")),
                    DataColumn(label: Text("Total")),
                  ],
                  rows: menuData.map((item) {
                    final qty = item['qty'] as int;
                    final price = item['price'] as double;
                    return DataRow(
                      cells: [
                        DataCell(Text(item['name'])),
                        DataCell(
                          Row(
                            children: [
                              Text(
                                "\u00D7$qty",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text("\$${(qty * price).toStringAsFixed(2)}"),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                _buildRow("Subtotal", subtotal),
                _buildRow("Tax (8.5%)", tax),
                _buildRow("Tip", tip),
                Divider(),
                _buildRow("Total", total, isTotal: true),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _captureAndSharePDF(context); // Capture and share the PDF
                    },
                    child: Text(
                      "Confirm & Add to Table (\$${total.toStringAsFixed(2)})",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Capture widget and share as PDF
  Future<void> _captureAndSharePDF(BuildContext context) async {
    try {
      // Capture the widget as image
      RenderRepaintBoundary boundary =
      _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save the image as a PDF
      final pdfFile = await _createPdfFromImage(pngBytes);

      // Share the PDF to WhatsApp with summary text
      await sharePdfToWhatsApp(pdfFile, subtotal, subtotal * 0.085, subtotal * 0.15, subtotal + (subtotal * 0.085) + subtotal * 0.15);
    } catch (e) {
      print("Error: $e");
    }
  }

  // Convert image bytes to PDF and save the file
  Future<File> _createPdfFromImage(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(imageBytes);

    // Add image to PDF
    pdf.addPage(pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Center the image
            pw.Center(child: pw.Image(pdfImage)),
            pw.SizedBox(height: 20),  // Add space between image and text

            // Add bill summary
            pw.Text('Bill Summary:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Subtotal: \$${subtotal.toStringAsFixed(2)}'),
            pw.Text('Tax (8.5%): \$${(subtotal * 0.085).toStringAsFixed(2)}'),
            pw.Text('Tip (15%): \$${(subtotal * 0.15).toStringAsFixed(2)}'),
            pw.Divider(),
            pw.Text(
              'Total: \$${(subtotal + (subtotal * 0.085) + (subtotal * 0.15)).toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        );
      },
    ));

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/cart_page_with_summary.pdf");
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // Share PDF file to WhatsApp
  Future<void> sharePdfToWhatsApp(File pdfFile, double subtotal, double tax, double tip, double total) async {
    try {
      // Convert the File to XFile
      XFile xFile = XFile(pdfFile.path);

      // Prepare the summary text (in case you want to add it to the share message)
      String billSummary = '''
    Bill Summary:
    ----------------------
    Subtotal: \$${subtotal.toStringAsFixed(2)}
    Tax (8.5%): \$${tax.toStringAsFixed(2)}
    Tip (15%): \$${tip.toStringAsFixed(2)}
    ----------------------
    Total: \$${total.toStringAsFixed(2)}
    ''';

      // Share the PDF and the bill summary text
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: billSummary, // Include the bill summary here
        ),
      );
    } catch (e) {
      print("Error sharing the file: $e");
    }
  }

  // Helper method for building rows in the summary
  Widget _buildRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "\$${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}



