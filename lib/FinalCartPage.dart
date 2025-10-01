import 'dart:io';
import 'dart:typed_data';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter_sms/flutter_sms.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'Styles/my_colors.dart';
import 'Styles/my_font.dart'; // <-- for formatting

/// Cart Page
class FinalCartPage extends StatelessWidget {
  final List<Map<String, dynamic>> menuData;
  final String table;
  final void Function(List<Map<String, dynamic>> selectedItems) onConfirm;

  FinalCartPage({
    required this.menuData,
    required this.onConfirm,
    required this.table,
  });

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
            child: menuData.isEmpty
                ? Center(child: Text("No items in cart"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateColor.resolveWith(
                        (states) => primary_color.withOpacity(0.1),
                      ),
                      columns: const [
                        DataColumn(label: Text("Item")),
                        DataColumn(label: Text("Qty")),
                        // DataColumn(label: Text("Price")),
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
                                      fontFamily: fontMulishSemiBold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // DataCell(Text("\$${price.toStringAsFixed(2)}")),
                            DataCell(
                              Text(
                                "\$${(qty * price).toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontFamily: fontMulishSemiBold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
                      // Step 1: Generate PDF bytes in memory
                      final pdfBytes = await generateCartPdfBytes(menuData);

                      // String bill = (await uploadPdfOnSupraBase(
                      //   pdfBytes,
                      //   "Bill",
                      // ));
                      // print("Bill" + bill);
                      //
                      // await sendWhatsappMessage(
                      //   "919737388786",
                      //   "Hello! Here is your bill.\n" + bill,
                      // );

                      //  sendPdfLink("Hiii", "919737388786");

                      // Step 2: Show PDF preview
                      await Printing.layoutPdf(
                        onLayout: (format) async => pdfBytes,
                        name: "Cart Summary",
                        usePrinterSettings: false,
                      );

                      // ✅ Save transaction to Firestore
                      await addTransactionToFirestore(
                        items: menuData,
                        tableName: table,
                        subtotal: subtotal,
                        tax: tax,
                        tip: tip,
                        total: total,
                      );

                      // Clear cart
                      onConfirm([]);

                      //
                      // // Step 3: After preview, open Name + Mobile dialog
                      // final _nameController = TextEditingController();
                      // final _mobileController = TextEditingController();
                      //
                      // showDialog(
                      //   context: context,
                      //   builder: (ctx) {
                      //     return AlertDialog(
                      //       title: Text("Send Cart to WhatsApp"),
                      //       content: Column(
                      //         mainAxisSize: MainAxisSize.min,
                      //         children: [
                      //           TextField(
                      //             controller: _nameController,
                      //             decoration: InputDecoration(
                      //               labelText: "Name",
                      //               border: OutlineInputBorder(),
                      //             ),
                      //           ),
                      //           SizedBox(height: 10),
                      //           TextField(
                      //             controller: _mobileController,
                      //             keyboardType: TextInputType.phone,
                      //             decoration: InputDecoration(
                      //               labelText:
                      //                   "Mobile Number (with country code)",
                      //               border: OutlineInputBorder(),
                      //             ),
                      //           ),
                      //         ],
                      //       ),
                      //       actions: [
                      //         TextButton(
                      //           onPressed: () => Navigator.pop(ctx),
                      //           child: Text("Cancel"),
                      //         ),
                      //         ElevatedButton(
                      //           onPressed: () async {
                      //             final name = _nameController.text.trim();
                      //             final mobile = _mobileController.text.trim();
                      //
                      //             if (mobile.isEmpty) return;
                      //
                      //             Navigator.pop(ctx);
                      //             // Step 4: Call method to send PDF
                      //             await sendPdfToWhatsAppNew(pdfBytes, mobile);
                      //           },
                      //           child: Text("Send"),
                      //         ),
                      //       ],
                      //     );
                      //   },
                      // );
                    },
                    child: Text(
                      "Confirm & Go For Billing (\$${total.toStringAsFixed(2)})",
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

  Widget _buildRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: isTotal ? fontMulishSemiBold : fontMulishRegular,
            ),
          ),
          Text(
            "\$${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontFamily: isTotal ? fontMulishSemiBold : fontMulishRegular,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> generateCartPdf(List<Map<String, dynamic>> menuData) async {
    final pdf = pw.Document();

    double subtotal = 0;
    for (var item in menuData) {
      subtotal += (item['qty'] as int) * (item['price'] as double);
    }
    final tax = subtotal * 0.085;
    final tip = subtotal * 0.15;
    final total = subtotal + tax + tip;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Cart Summary",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.Table.fromTextArray(
                headers: ["Item", "Qty", "Total"],
                data: menuData.map((item) {
                  final qty = item['qty'] as int;
                  final price = item['price'] as double;
                  return [
                    item['name'],
                    "×$qty",
                    "\$${(qty * price).toStringAsFixed(2)}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.orange),
                border: pw.TableBorder.all(color: PdfColors.grey),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: pw.TextStyle(fontSize: 12),
              ),

              pw.SizedBox(height: 20),
              _buildSummaryRow("Subtotal", subtotal),
              _buildSummaryRow("Tax (8.5%)", tax),
              _buildSummaryRow("Tip", tip),
              pw.Divider(),
              _buildSummaryRow("Total", total, bold: true),
            ],
          );
        },
      ),
    );

    // Preview or share PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<File> generateCartPdfForShare(
    List<Map<String, dynamic>> menuData,
  ) async {
    final pdf = pw.Document();

    double subtotal = 0;
    for (var item in menuData) {
      subtotal += (item['qty'] as int) * (item['price'] as double);
    }
    final tax = subtotal * 0.085;
    final tip = subtotal * 0.15;
    final total = subtotal + tax + tip;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Cart Summary",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ["Item", "Qty", "Total"],
                data: menuData.map((item) {
                  final qty = item['qty'] as int;
                  final price = item['price'] as double;
                  return [
                    item['name'],
                    "×$qty",
                    "\$${(qty * price).toStringAsFixed(2)}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.orange),
                border: pw.TableBorder.all(color: PdfColors.grey),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              _buildSummaryRow("Subtotal", subtotal),
              _buildSummaryRow("Tax (8.5%)", tax),
              _buildSummaryRow("Tip", tip),
              pw.Divider(),
              _buildSummaryRow("Total", total, bold: true),
            ],
          );
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/cart_summary.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildSummaryRow(String label, double value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            "\$${value.toStringAsFixed(2)}",
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendPdfToWhatsApp(
    List<Map<String, dynamic>> menuData,
    String phoneNumber,
  ) async {
    final pdfFile = await generateCartPdfForShare(menuData);

    // Step 1: Open WhatsApp chat with that number
    final whatsappUrl = Uri.parse("https://wa.me/$phoneNumber");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }

    // Step 2: Share the PDF file (user selects WhatsApp)
    await Share.shareXFiles([
      XFile(pdfFile.path),
    ], text: "Here is your cart summary");
  }

  void showWhatsAppDialog(
    BuildContext context,
    List<Map<String, dynamic>> menuData,
  ) {
    final _nameController = TextEditingController();
    final _mobileController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Send Cart to WhatsApp"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Mobile Number (with country code)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final mobile = _mobileController.text.trim();

                if (mobile.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter mobile number")),
                  );
                  return;
                }

                Navigator.pop(ctx); // close dialog

                await sendPdfToWhatsApp(menuData, mobile); // call your method
              },
              child: Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  // Generate PDF in memory
  Future<Uint8List> generateCartPdfBytes(
    List<Map<String, dynamic>> menuData, {
    String? customerName,
  }) async {
    final pdf = pw.Document();

    double subtotal = 0;
    for (var item in menuData) {
      subtotal += (item['qty'] as int) * (item['price'] as double);
    }
    final tax = subtotal * 0.085;
    final tip = subtotal * 0.15;
    final total = subtotal + tax + tip;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (customerName != null && customerName.isNotEmpty)
                pw.Text(
                  "Customer: $customerName",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Cart Summary",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ["Item", "Qty", "Total"],
                data: menuData.map((item) {
                  final qty = item['qty'] as int;
                  final price = item['price'] as double;
                  return [
                    item['name'],
                    "×$qty",
                    "\$${(qty * price).toStringAsFixed(2)}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.orange),
                border: pw.TableBorder.all(color: PdfColors.grey),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              _buildSummaryRowForSendWhatsapp("Subtotal", subtotal),
              _buildSummaryRowForSendWhatsapp("Tax (8.5%)", tax),
              _buildSummaryRowForSendWhatsapp("Tip", tip),
              pw.Divider(),
              _buildSummaryRowForSendWhatsapp("Total", total, bold: true),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRowForSendWhatsapp(
    String label,
    double value, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            "\$${value.toStringAsFixed(2)}",
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendPdfToWhatsAppNew(
    Uint8List pdfBytes,
    String phoneNumber,
  ) async {
    // Step 1: Open WhatsApp chat
    final whatsappUrl = Uri.parse("https://wa.me/$phoneNumber");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }

    // Step 2: Share PDF in memory (user selects WhatsApp)
    await Share.shareXFiles([
      XFile.fromData(
        pdfBytes,
        name: "cart_summary.pdf",
        mimeType: "application/pdf",
      ),
    ], text: "Here is your cart summary");
  }

  Future<List<Uint8List>> pdfToImages(Uint8List pdfBytes) async {
    // Get raster pages as a list
    final List<pw.PdfRaster> pages = await Printing.raster(pdfBytes).toList();

    List<Uint8List> pngBytes = [];
    for (final page in pages) {
      final img = await page.toPng();
      pngBytes.add(img);
    }

    return pngBytes;
  }

  Future<void> sharePdfImages(List<Uint8List> images) async {
    List<XFile> files = images
        .map(
          (img) => XFile.fromData(img, name: "bill.png", mimeType: "image/png"),
        )
        .toList();

    await Share.shareXFiles(files, text: "Here is your bill");
  }

  // Future sendSMSImage(String message, List<String> recipients) async {
  //   String result = await sendSMS(message: message, recipients: recipients)
  //       .catchError((onError) {
  //         print(onError);
  //       });
  //   print(result);
  // }

  Future<void> sendWhatsappMessage(String phoneNumber, String message) async {
    // phoneNumber must include country code, e.g. "919876543210"
    final url = Uri.parse(
      "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not launch WhatsApp";
    }
  }

  Future<void> sendImage(Uint8List imageBytes, String phoneNumber) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/image.png');
    await file.writeAsBytes(imageBytes);

    final uri = Uri.parse('sms:$phoneNumber');
    // Android MMS supports "file://" URIs with intent, but url_launcher can't attach files directly
    // So you would need platform channel to send MMS with attachment
    await launchUrl(uri);
  }

  Future<String> uploadPdf(Uint8List pdfBytes, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'pdfs/$fileName.pdf',
      );
      final uploadTask = await storageRef.putData(pdfBytes);

      if (uploadTask.state == TaskState.success) {
        return await storageRef.getDownloadURL();
      } else {
        throw Exception("Upload failed: ${uploadTask.state}");
      }
    } catch (e) {
      print("Error uploading PDF: $e");
      rethrow;
    }
  }

  //
  // Future<void> sendPdfLink(String pdfUrl, String phoneNumber) async {
  //   String message = "Here is your PDF: $pdfUrl";
  //   await sendSMS(
  //     message: message,
  //     recipients: [phoneNumber],
  //   ).catchError((e) => print("Error sending SMS: $e"));
  // }

  Future<void> addTransactionToFirestore({
    required List<Map<String, dynamic>> items,
    required String tableName,
    required double subtotal,
    required double tax,
    required double tip,
    required double total,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat("yyyy-MM-dd").format(now); // e.g. "2025-10-01"

      final batch = FirebaseFirestore.instance.batch();

      // 🔹 1. Add transaction
      final txRef = FirebaseFirestore.instance.collection("transactions").doc();
      batch.set(txRef, {
        "table": tableName,
        "items": items
            .map(
              (e) => {
                "name": e["name"],
                "qty": e["qty"],
                "price": e["price"],
                "total": (e["qty"] as int) * (e["price"] as double),
              },
            )
            .toList(),
        "subtotal": subtotal,
        "tax": tax,
        "tip": tip,
        "total": total,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 🔹 2. Update daily_stats
      final dailyRef = FirebaseFirestore.instance
          .collection("daily_stats")
          .doc(dateKey);

      batch.set(
        dailyRef,
        {
          "revenue": FieldValue.increment(total),
          "transactions": FieldValue.increment(1),
          "lastUpdated": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // Merge ensures existing doc is updated
      );

      // 🔹 3. Update global summary
      final summaryRef = FirebaseFirestore.instance
          .collection("stats")
          .doc("summary");

      batch.set(summaryRef, {
        "totalRevenue": FieldValue.increment(total),
        "totalTransactions": FieldValue.increment(1),
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔹 Commit both together
      await batch.commit();
      print("✅ Transaction + Daily Stats updated!");
    } catch (e) {
      print("❌ Error saving transaction: $e");
    }
  }
}
