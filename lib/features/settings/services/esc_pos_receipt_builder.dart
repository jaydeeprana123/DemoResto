import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:smartKitchen/core/services/restaurant_print_profile_service.dart';
import 'package:smartKitchen/core/utils/tax_calculator.dart';
import 'package:smartKitchen/features/ordering/services/food_bill_pdf_service.dart';
import 'package:smartKitchen/features/settings/services/print_settings.dart';
import 'package:get/get.dart';

/// Builds ESC/POS byte payloads for 58mm / 80mm Bluetooth thermal printers.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  static const _legacyRestaurantAddress =
      '05, Ground Floor, Ayesha Complex, Tandalja, Opposite JP Police Station, Diwalipura, Vadodara';
  static const _legacyRestaurantPhone = '+91 85113 33998';
  static const _legacyRestaurantName = 'AL - HAADI';

  static Future<List<int>> buildReceiptBytes(
    FoodBillPdfData data, {
    PosPrinterType printerType = PosPrinterType.narrow58,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = printerType == PosPrinterType.narrow58
        ? PaperSize.mm58
        : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    final now = DateTime.now();
    final invoiceNo = _formatInvoiceNumber(data.invoiceNumber, now);
    final dateText = DateFormat('dd/MM/yyyy').format(now);
    final timeText = DateFormat('hh:mm a').format(now);

    bytes.addAll(generator.reset());

    final includeLogo = await PrintSettings.getBillPdfIncludeLogos();
    final thermalLogo = includeLogo
        ? await _thermalLogoImage(printerType: printerType)
        : null;
    if (thermalLogo != null) {
      bytes.addAll(
        generator.imageRaster(
          thermalLogo,
          align: PosAlign.center,
        ),
      );
      bytes.addAll(generator.feed(1));
    } else {
      bytes.addAll(
        generator.text(
          _headerRestaurantName,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        _headerRestaurantAddress,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _headerRestaurantPhonesLine,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(data.receiptCustomerLabelLine));
    bytes.addAll(generator.row([
      PosColumn(
        text: 'Bill ID: $invoiceNo',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: dateText,
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(
      generator.text(
        timeText,
        styles: const PosStyles(align: PosAlign.right),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'ITEM',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'QTY',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: 'RATE',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: 'AMT',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(generator.hr());

    for (final item in data.items) {
      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toDouble() ??
          double.tryParse(item['price']?.toString() ?? '') ??
          0;
      final lineTotal = price * qty;
      final name = item['name']?.toString() ?? '-';

      bytes.addAll(generator.text(name));
      bytes.addAll(
        generator.row([
          PosColumn(text: '', width: 6),
          PosColumn(
            text: '$qty',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: _formatMoney(price),
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: _formatMoney(lineTotal),
            width: 2,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]),
      );
    }

    bytes.addAll(generator.hr());
    bytes.addAll(
      _amountRow(generator, 'Subtotal', data.subtotal.toDouble()),
    );
    if (data.cgstPercentage > 0 && data.cgstAmount > 0) {
      bytes.addAll(
        _amountRow(
          generator,
          'CGST @ ${TaxCalculator.formatPercent(data.cgstPercentage)}%',
          data.cgstAmount.toDouble(),
        ),
      );
    }
    if (data.sgstPercentage > 0 && data.sgstAmount > 0) {
      bytes.addAll(
        _amountRow(
          generator,
          'SGST @ ${TaxCalculator.formatPercent(data.sgstPercentage)}%',
          data.sgstAmount.toDouble(),
        ),
      );
    }
    if (data.discount > 0) {
      bytes.addAll(
        _amountRow(generator, 'Discount', -data.discount.toDouble()),
      );
    }
    if (data.extra > 0) {
      bytes.addAll(
        _amountRow(generator, 'Extra', data.extra.toDouble()),
      );
    }
    bytes.addAll(generator.hr(ch: '=', linesAfter: 0));
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: 'Rs. ${_formatMoney(data.total)}',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      ]),
    );
    bytes.addAll(generator.hr(ch: '=', linesAfter: 0));

    if (data.cashAmount > 0) {
      bytes.addAll(
        _amountRow(generator, 'Cash', data.cashAmount.toDouble()),
      );
    }
    if (data.onlineAmount > 0) {
      bytes.addAll(
        _amountRow(generator, 'Online', data.onlineAmount.toDouble()),
      );
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'Powered By',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Smart Kitchen',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    final showQr = await PrintSettings.getBillPrintShowQrCode();
    if (showQr) {
      final thermalQr = await _thermalQrImage(printerType: printerType);
      if (thermalQr != null) {
        bytes.addAll(generator.feed(1));
        bytes.addAll(
          generator.imageRaster(
            thermalQr,
            align: PosAlign.center,
          ),
        );
      }
    }
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static Future<List<int>> buildTestReceiptBytes({
    PosPrinterType printerType = PosPrinterType.narrow58,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = printerType == PosPrinterType.narrow58
        ? PaperSize.mm58
        : PaperSize.mm80;
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        'Smart Kitchen',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'Bluetooth printer test',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'If you can read this, your thermal printer is connected correctly.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static List<int> _amountRow(Generator generator, String label, double amount) {
    final prefix = amount < 0 ? '-Rs.' : 'Rs.';
    return generator.row([
      PosColumn(text: label, width: 8),
      PosColumn(
        text: '$prefix ${_formatMoney(amount.abs())}',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  /// Decodes the saved restaurant logo (or the same PDF fallback asset) into a
  /// 1-bit-friendly raster sized for 58mm / 80mm thermal paper.
  static Future<img.Image?> _thermalLogoImage({
    required PosPrinterType printerType,
  }) async {
    final bytes = await _loadThermalLogoBytes();
    if (bytes == null || bytes.isEmpty) return null;

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return null;
      }

      final paperDots = printerType == PosPrinterType.narrow58 ? 384 : 576;
      // Leave side margins so cheap 58mm heads do not clip the logo.
      final maxWidth = _alignToRasterWidth((paperDots * 0.72).round());
      final maxHeight = printerType == PosPrinterType.narrow58 ? 140 : 180;
      final target = _thermalLogoTargetSize(
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      var prepared = _flattenOnWhite(decoded);
      prepared = img.copyResize(
        prepared,
        width: target.width,
        height: target.height,
        interpolation: img.Interpolation.linear,
      );
      prepared = img.grayscale(prepared);
      return prepared;
    } catch (_) {
      return null;
    }
  }

  /// Uploaded restaurant QR only. There is no asset fallback.
  static Future<img.Image?> _thermalQrImage({
    required PosPrinterType printerType,
  }) async {
    if (!Get.isRegistered<RestaurantPrintProfileService>()) return null;
    final profile = Get.find<RestaurantPrintProfileService>();
    await profile.ensureQrCodeReady();
    final bytes = profile.qrCodeBytes;
    if (bytes == null || bytes.isEmpty) return null;

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return null;
      }

      final paperDots = printerType == PosPrinterType.narrow58 ? 384 : 576;
      final side = _alignToRasterWidth((paperDots * 0.48).round());
      final aspect = decoded.width / decoded.height;
      final width = aspect >= 1 ? side : _alignToRasterWidth((side * aspect).round());
      final height = aspect >= 1 ? (side / aspect).round() : side;

      final targetWidth = width.clamp(8, side).toInt();
      final targetHeight = height.clamp(8, side).toInt();

      var prepared = _flattenOnWhite(decoded);
      prepared = img.copyResize(
        prepared,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
      prepared = img.grayscale(prepared);
      return prepared;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _loadThermalLogoBytes() async {
    if (Get.isRegistered<RestaurantPrintProfileService>()) {
      final profile = Get.find<RestaurantPrintProfileService>();
      await profile.ensureLogoReady();
      final fromProfile = profile.logoBytes;
      if (fromProfile != null && fromProfile.isNotEmpty) {
        return fromProfile;
      }
    }

    try {
      final data = await rootBundle.load(
        'assets/images/restaurant_bill_logo.png',
      );
      if (data.lengthInBytes <= 0) return null;
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static img.Image _flattenOnWhite(img.Image source) {
    final flattened = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 3,
    );
    img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flattened, source);
    return flattened;
  }

  static ({int width, int height}) _thermalLogoTargetSize({
    required int imageWidth,
    required int imageHeight,
    required int maxWidth,
    required int maxHeight,
  }) {
    final aspect = imageWidth / imageHeight;
    late final double boxW;
    late final double boxH;
    if (aspect >= 1.5) {
      boxW = maxWidth.toDouble();
      boxH = maxHeight.toDouble();
    } else if (aspect <= 0.8) {
      boxW = maxWidth * 0.55;
      boxH = maxHeight * 0.85;
    } else {
      final side = maxHeight * 0.75;
      final halfWidth = maxWidth * 0.55;
      boxW = side < halfWidth ? side : halfWidth;
      boxH = side;
    }

    var width = boxW;
    var height = width / aspect;
    if (height > boxH) {
      height = boxH;
      width = height * aspect;
    }

    var widthDots = _alignToRasterWidth(width.round().clamp(8, maxWidth));
    var heightDots = height.round().clamp(8, maxHeight);
    if (widthDots / aspect > maxHeight) {
      heightDots = maxHeight;
      widthDots = _alignToRasterWidth((heightDots * aspect).round().clamp(8, maxWidth));
    } else {
      heightDots = (widthDots / aspect).round().clamp(8, maxHeight);
    }
    return (width: widthDots, height: heightDots);
  }

  static int _alignToRasterWidth(int width) {
    final aligned = (width ~/ 8) * 8;
    return aligned < 8 ? 8 : aligned;
  }

  static String get _headerRestaurantName {
    final profile = Get.isRegistered<RestaurantPrintProfileService>()
        ? Get.find<RestaurantPrintProfileService>()
        : null;
    final name = profile?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return _legacyRestaurantName;
  }

  static String get _headerRestaurantAddress {
    final profile = Get.isRegistered<RestaurantPrintProfileService>()
        ? Get.find<RestaurantPrintProfileService>()
        : null;
    final address = profile?.address?.trim();
    if (address != null && address.isNotEmpty) return address;
    return _legacyRestaurantAddress;
  }

  static String get _headerRestaurantPhonesLine {
    final profile = Get.isRegistered<RestaurantPrintProfileService>()
        ? Get.find<RestaurantPrintProfileService>()
        : null;
    final line = profile?.displayMobilesLine.trim();
    if (line != null && line.isNotEmpty) return line;
    return _legacyRestaurantPhone;
  }

  static String _formatInvoiceNumber(String? id, DateTime now) {
    if (id != null && id.trim().isNotEmpty) {
      final trimmed = id.trim();
      if (trimmed.startsWith('BILL-')) return trimmed;
      if (trimmed.length >= 4) {
        return trimmed.substring(trimmed.length - 4).toUpperCase();
      }
      return trimmed.toUpperCase();
    }
    return DateFormat('HHmm').format(now);
  }

  static String _formatMoney(num value) => value.abs().toStringAsFixed(2);
}
