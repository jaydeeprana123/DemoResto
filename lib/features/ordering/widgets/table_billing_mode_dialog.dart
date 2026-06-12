import 'package:demo/Styles/my_font.dart';
import 'package:flutter/material.dart';

enum TableBillingMode {
  /// Transaction saved; table cleared (take-away deleted).
  paid,

  /// Transaction saved; table stays with PAID tag and items visible.
  paidWithoutServing,
}

enum BillReceiptAction {
  withoutPrint,
  print,
  shareWhatsApp,
}

class TableBillingDialogResult {
  const TableBillingDialogResult({
    required this.mode,
    required this.receiptAction,
  });

  final TableBillingMode mode;
  final BillReceiptAction receiptAction;
}

Future<TableBillingDialogResult?> showTableBillingModeDialog(
  BuildContext context, {
  required double total,
  String? tableName,
}) {
  var receiptAction = BillReceiptAction.withoutPrint;

  return showDialog<TableBillingDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        TableBillingDialogResult result(TableBillingMode mode) {
          return TableBillingDialogResult(
            mode: mode,
            receiptAction: receiptAction,
          );
        }

        Widget receiptRadio(BillReceiptAction value, String label) {
          return Expanded(
            child: InkWell(
              onTap: () => setDialogState(() => receiptAction = value),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<BillReceiptAction>(
                    value: value,
                    groupValue: receiptAction,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => receiptAction = v);
                    },
                  ),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Billing',
                      style: TextStyle(
                        fontFamily: fontMulishSemiBold,
                        fontSize: 18,
                        color: Color(0xFF1A3A5C),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf57c35).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFf57c35).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: 16,
                        color: Color(0xFFf57c35),
                      ),
                    ),
                  ),
                ],
              ),
              if (tableName != null && tableName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tableName,
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bill delivery',
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              receiptRadio(BillReceiptAction.withoutPrint, 'Without Print'),
              receiptRadio(BillReceiptAction.print, 'Print'),
              receiptRadio(
                BillReceiptAction.shareWhatsApp,
                'Share PDF on WhatsApp',
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how to complete billing:',
                style: TextStyle(
                  fontFamily: fontMulishRegular,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              _ModeButton(
                icon: Icons.check_circle_outline,
                label: 'Paid',
                subtitle: 'Save bill, clear table (delete take-away)',
                color: const Color(0xFF4CAF50),
                onTap: () => Navigator.pop(ctx, result(TableBillingMode.paid)),
              ),
              const SizedBox(height: 10),
              _ModeButton(
                icon: Icons.receipt_long_outlined,
                label: 'Paid Without Serving',
                subtitle: 'Save bill, keep order with PAID tag',
                color: const Color(0xFFf57c35),
                onTap: () => Navigator.pop(
                  ctx,
                  result(TableBillingMode.paidWithoutServing),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: fontMulishSemiBold),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<BillReceiptAction?> showBillReceiptOptionsDialog(
  BuildContext context, {
  String? billId,
}) {
  return showDialog<BillReceiptAction>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Bill',
        style: TextStyle(
          fontFamily: fontMulishSemiBold,
          fontSize: 18,
          color: Color(0xFF1A3A5C),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (billId != null && billId.isNotEmpty) ...[
            Text(
              'Bill ID: $billId',
              style: TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Choose how to deliver the bill:',
            style: TextStyle(
              fontFamily: fontMulishRegular,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          _ModeButton(
            icon: Icons.share_outlined,
            label: 'Share PDF',
            subtitle: 'Generate and share the PDF bill',
            color: const Color(0xFF25D366),
            onTap: () => Navigator.pop(ctx, BillReceiptAction.shareWhatsApp),
          ),
          const SizedBox(height: 10),
          _ModeButton(
            icon: Icons.print_outlined,
            label: 'Print',
            subtitle: 'Print the bill directly',
            color: const Color(0xFF1A3A5C),
            onTap: () => Navigator.pop(ctx, BillReceiptAction.print),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: fontMulishSemiBold),
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: fontMulishRegular,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
