import 'package:flutter/material.dart';

class EditableTotalRow extends StatelessWidget {
  const EditableTotalRow({
    super.key,
    required this.total,
    required this.isEditing,
    required this.controller,
    required this.onEditPressed,
    required this.onApplyPressed,
    this.accentColor = const Color(0xFFf57c35),
  });

  final int total;
  final bool isEditing;
  final TextEditingController controller;
  final VoidCallback onEditPressed;
  final VoidCallback onApplyPressed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing)
              SizedBox(
                width: 96,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: '₹',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onApplyPressed(),
                ),
              )
            else
              Text(
                '₹$total',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                isEditing ? Icons.check_rounded : Icons.edit_rounded,
                size: 20,
              ),
              color: accentColor,
              tooltip: isEditing ? 'Apply total' : 'Edit total',
              onPressed: isEditing ? onApplyPressed : onEditPressed,
            ),
          ],
        ),
      ],
    );
  }
}
