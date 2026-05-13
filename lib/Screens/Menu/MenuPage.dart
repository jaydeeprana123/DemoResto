import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:demo/models/agent_response.dart';
import 'package:demo/services/ai_order_service.dart';

import 'package:demo/CartPage.dart';
import 'package:demo/MyWidgets/EditableTextField.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'MenuController.dart' as mc;

// ── Brand colours ─────────────────────────────────
const _kNavy = Color(0xFF1A3A5C);
const _kOrange = Color(0xFFf57c35);

class MenuPage extends StatelessWidget {
  final void Function(
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
    String tableName,
    String overallRemarks,
  ) onConfirm;
  final List<Map<String, dynamic>> menuList;
  final List<Map<String, dynamic>> initialItems;
  final String tableName;
  final bool tableNameEditable;
  final bool showBilling;
  final bool isFromFinalBilling;

  MenuPage({
    required this.onConfirm,
    required this.menuList,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    required this.isFromFinalBilling,
    this.initialItems = const [],
    Key? key,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showVoiceOrderSheet(BuildContext context, mc.MenuController controller) {
    controller.startVoiceRecording(context);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return Obx(() {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Mic icon with colour state + amplitude ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (controller.isRecording.value)
                      Container(
                        width: 56 + (controller.currentAmplitude.value * 20),
                        height: 56 + (controller.currentAmplitude.value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(
                            alpha: 0.15 + controller.currentAmplitude.value * 0.15,
                          ),
                        ),
                      ),
                    Icon(
                      controller.isRecording.value ? Icons.mic : Icons.mic_none,
                      size: 40,
                      color: controller.isRecording.value ? Colors.red : Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title + subtitle
                const Text(
                  'Voice Order',
                  style: TextStyle(
                    fontSize: 17,
                    fontFamily: fontMulishBold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.isRecording.value
                      ? '🔴 Recording ${_formatDuration(controller.recordingSeconds.value)} — speak your order'
                      : controller.isTranscribing.value
                      ? '⏳ Transcribing with Sarvam AI…'
                      : controller.recognizedText.value.isNotEmpty
                      ? 'Transcript ready'
                      : 'Tap Start, then speak your full order',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: controller.isRecording.value
                        ? Colors.red.shade700
                        : controller.isTranscribing.value
                        ? Colors.blue.shade700
                        : Colors.grey.shade600,
                    fontFamily: fontMulishRegular,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by Sarvam AI • Hindi, Gujarati, English',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontFamily: fontMulishRegular,
                  ),
                ),
                const SizedBox(height: 14),

                // Transcript / recording indicator area
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 64,
                    maxHeight: 120,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: controller.isRecording.value
                        ? Colors.red.shade50
                        : controller.isTranscribing.value
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: controller.isRecording.value
                          ? Colors.red.shade200
                          : controller.isTranscribing.value
                          ? Colors.blue.shade200
                          : Colors.grey.shade300,
                      width: controller.isRecording.value || controller.isTranscribing.value ? 1.5 : 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: controller.isRecording.value
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(7, (i) {
                                    final barHeight =
                                        8.0 + (controller.currentAmplitude.value * 24 * (i.isEven ? 1.0 : 0.6));
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: 4,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Speak items, quantities & remarks…',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade300,
                                    fontFamily: fontMulishRegular,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : controller.isTranscribing.value
                        ? Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Recognising speech…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade600,
                                    fontFamily: fontMulishRegular,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            controller.recognizedText.value.isEmpty
                                ? 'e.g. "do chicken tikka rice aur teen malai tikka less spicy"'
                                : controller.recognizedText.value,
                            style: TextStyle(
                              fontSize: 13,
                              color: controller.recognizedText.value.isEmpty
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              fontFamily: fontMulishRegular,
                              fontStyle: controller.recognizedText.value.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                if (controller.isProcessing.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Processing with AI…',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (controller.isProcessing.value || controller.isTranscribing.value)
                            ? null
                            : () {
                                controller.cancelRecording();
                                Navigator.pop(sheetContext);
                              },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: (controller.isProcessing.value || controller.isTranscribing.value)
                          ? ElevatedButton.icon(
                              onPressed: null,
                              icon: const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              label: Text(
                                controller.isTranscribing.value ? 'Transcribing…' : 'Processing…',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: controller.isTranscribing.value
                                    ? Colors.blue.shade600
                                    : Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            )
                          : controller.isRecording.value
                          ? ElevatedButton.icon(
                              onPressed: () {
                                controller.stopAndTranscribe();
                              },
                              icon: const Icon(Icons.stop_circle_outlined, size: 20),
                              label: const Text('Stop & Process'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                controller.startVoiceRecording(sheetContext);
                              },
                              icon: const Icon(Icons.mic, size: 20),
                              label: Text(controller.recognizedText.value.isEmpty ? 'Start' : 'Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    ).whenComplete(() {
      controller.cancelRecording();
    });
  }

  Widget buildVoiceOrderDialog(mc.MenuController controller, BuildContext context, List<OrderResult> items, String title, bool isSuggestion, String transcript, {double confidence = 1.0}) {
    if (items.isEmpty) return const SizedBox.shrink();

    final editableItems = List<OrderResult>.from(items).obs;
    final remarkControllers = editableItems.map((r) => TextEditingController(text: r.remarks)).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: BoxDecoration(
              color: isSuggestion ? Colors.orange.shade700 : const Color(0xFF1A3A5C),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  isSuggestion ? Icons.help_outline : Icons.mic,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: fontMulishBold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSuggestion)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'AI Confidence: ${(confidence * 100).toStringAsFixed(0)}%  •  Review items below',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontFamily: fontMulishRegular,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: Obx(() {
              if (editableItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.remove_shopping_cart,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All items removed.\nTap Cancel or try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontFamily: fontMulishRegular,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: editableItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final r = editableItems[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isSuggestion
                            ? Colors.orange.shade200
                            : const Color(0xFF1A3A5C).withValues(alpha: 0.25),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSuggestion ? Colors.orange.shade600 : const Color(0xFFf57c35),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.item['name'] as String? ?? '',
                                          style: const TextStyle(
                                            fontFamily: fontMulishBold,
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSuggestion
                                              ? Colors.orange.shade50
                                              : const Color(0xFF1A3A5C).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSuggestion
                                                ? Colors.orange.shade300
                                                : const Color(0xFF1A3A5C).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          'Qty: ${r.quantity}',
                                          style: TextStyle(
                                            fontFamily: fontMulishBold,
                                            fontSize: 12,
                                            color: isSuggestion ? Colors.orange.shade800 : const Color(0xFF1A3A5C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                remarkControllers[index].dispose();
                                editableItems.removeAt(index);
                                remarkControllers.removeAt(index);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Get.back();
                      Future.delayed(const Duration(milliseconds: 300), () => _showVoiceOrderSheet(context, controller));
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Obx(() {
                    return ElevatedButton.icon(
                      onPressed: editableItems.isEmpty
                          ? null
                          : () {
                              final updated = List.generate(
                                editableItems.length,
                                (i) => OrderResult(
                                  item: editableItems[i].item,
                                  quantity: editableItems[i].quantity,
                                  remarks: remarkControllers[i].text.trim(),
                                ),
                              );
                              Get.back();
                              controller.applyOrderResults(updated, transcript);
                              controller.agentService.saveOrderToHistory(updated).ignore();
                              Get.snackbar(
                                'Success',
                                '✅ ${updated.length} item(s) added to cart',
                                backgroundColor: Colors.green.shade700,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            },
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(editableItems.isEmpty ? 'Nothing to add' : 'Add to Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(mc.MenuController controller, String category, int index) {
    return Obx(() {
      final item = controller.menuData[category]![index];
      final qty = item['qty'] as int;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  controller.incrementQty(category, index);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'].toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: fontMulishBold,
                        color: Color(0xFF1A3A5C),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '₹${(item['price'] as num).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontFamily: fontMulishRegular,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (qty > 0)
                          Text(
                            'X $qty',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              fontFamily: fontMulishRegular,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            qty == 0
                ? _addButton(onTap: () => controller.incrementQty(category, index))
                : _stepper(
                    qty: qty,
                    lastQty: (item['lastQty'] as int?) ?? (qty - 1),
                    onDecrement: () => controller.decrementQty(category, index),
                    onIncrement: () => controller.incrementQty(category, index),
                  ),
          ],
        ),
      );
    });
  }

  Widget _addButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFf57c35), width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            fontSize: 13,
            fontFamily: fontMulishBold,
            color: Color(0xFFf57c35),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _stepper({
    required int qty,
    required int lastQty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final isIncrementing = qty >= lastQty;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 40,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          SizedBox(
            width: 26,
            height: 32,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final isIncoming = child.key == ValueKey<int>(qty);
                  Offset beginOffset;
                  if (isIncrementing) {
                    beginOffset = isIncoming ? const Offset(0, 1.0) : const Offset(0, -1.0);
                  } else {
                    beginOffset = isIncoming ? const Offset(0, -1.0) : const Offset(0, 1.0);
                  }
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: beginOffset,
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    )),
                    child: child,
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: Text(
                  '$qty',
                  key: ValueKey<int>(qty),
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: fontMulishBold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFf57c35),
                borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemarkEditSheet(BuildContext context, mc.MenuController controller, String category, int index) {
    final item = controller.menuData[category]![index];
    final ctrl = TextEditingController(text: (item['remarks'] ?? '').toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'].toString(),
              style: const TextStyle(fontSize: 15, fontFamily: fontMulishBold, color: Color(0xFF1A3A5C)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. less spicy, no onion, kam tel…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.notes_outlined, color: Colors.orange.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.orange.shade50,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  controller.updateRemark(category, index, ctrl.text.trim());
                  Navigator.pop(ctx);
                  ctrl.dispose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Save Remark', style: TextStyle(fontFamily: fontMulishBold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(mc.MenuController(
      initialMenuList: menuList,
      initialItems: initialItems,
      initialTableName: tableName,
    ));

    controller.showVoiceDialog = (items, title, isSuggestion, transcript, confidence) {
      Get.dialog(buildVoiceOrderDialog(controller, context, items, title, isSuggestion, transcript, confidence: confidence));
    };

    return Obx(() {
      final categories = controller.menuData.keys.toList();

      return DefaultTabController(
        length: controller.showAllCategories.value ? categories.length : controller.selectedCategories.length,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: _kNavy,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: controller.showSearch.value
                ? TextField(
                    controller: controller.searchController,
                    autofocus: true,
                    onChanged: (value) {
                      controller.searchQuery.value = value.toLowerCase();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search menu...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: fontMulishRegular,
                    ),
                  )
                : Row(
                    children: [
                      (tableName.contains("Table") || !tableNameEditable)
                          ? Text(
                              tableName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: fontMulishBold,
                                color: Colors.white,
                              ),
                            )
                          : Expanded(
                              child: EditableTextField(
                                controller: controller.tableNameController,
                                onEditingChanged: (value) {
                                  controller.isNameEdit.value = value;
                                },
                              ),
                            ),
                    ],
                  ),
            actions: [
              if (!controller.isNameEdit.value)
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.redAccent),
                  onPressed: () => _showVoiceOrderSheet(context, controller),
                  tooltip: "Voice Order",
                ),
              if (!controller.isNameEdit.value)
                IconButton(
                  icon: Icon(
                    controller.showSearch.value ? Icons.close : Icons.search,
                    color: Colors.white,
                  ),
                  onPressed: controller.toggleSearch,
                ),
              if (!controller.isNameEdit.value)
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () => _showCategoryFilterDialog(context, controller),
                      tooltip: "Filter by Category",
                    ),
                    if (!controller.showAllCategories.value && controller.selectedCategories.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _kOrange,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              '${controller.selectedCategories.length}',
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
            bottom: !controller.showSearch.value
                ? TabBar(
                    isScrollable: true,
                    indicatorColor: _kOrange,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontFamily: fontMulishSemiBold, fontSize: 13),
                    tabs: controller.showAllCategories.value
                        ? categories.map((c) => Tab(text: c)).toList()
                        : controller.selectedCategories.map((c) => Tab(text: c)).toList(),
                  )
                : null,
          ),
          body: Column(
            children: [
              Expanded(
                child: controller.showSearch.value
                    ? _buildGlobalSearchList(controller)
                    : controller.showAllCategories.value
                        ? TabBarView(
                            children: categories.map((category) {
                              final items = controller.menuData[category]!;
                              return ListView.builder(
                                itemCount: items.length,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemBuilder: (context, index) => _buildMenuItem(controller, category, index),
                              );
                            }).toList(),
                          )
                        : TabBarView(
                            children: controller.selectedCategories.map((category) {
                              final items = controller.menuData[category];
                              return ListView.builder(
                                itemCount: items?.length ?? 0,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemBuilder: (context, index) => _buildMenuItem(controller, category, index),
                              );
                            }).toList(),
                          ),
              ),
              if (controller.totalItems > 0)
                InkWell(
                  onTap: () {
                    final selectedItems = <Map<String, dynamic>>[];
                    controller.menuData.forEach((category, items) {
                      selectedItems.addAll(items.where((item) => item['qty'] > 0));
                    });

                    if (isFromFinalBilling) {
                      Navigator.pop(context, selectedItems);
                    } else {
                      Get.to(() => CartPage(
                            tableName: controller.tableNameController.text,
                            tableNameEditable: tableNameEditable,
                            menuData: selectedItems,
                            fullMenu: menuList,
                            overallRemarks: controller.overallRemarks.value,
                            onConfirm: onConfirm,
                            showBilling: showBilling,
                          ))?.then((onValue) {
                        if (onValue != null) {
                          controller.syncItemsFromCart(onValue);
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1ABC9C),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${controller.totalItems} items | ₹${controller.totalPrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  void _showCategoryFilterDialog(BuildContext context, mc.MenuController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final categories = controller.menuData.keys.toList();

        return Obx(() {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "Filter by Category",
              style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text(
                      "All Categories",
                      style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 15),
                    ),
                    value: controller.showAllCategories.value,
                    activeColor: Colors.green,
                    onChanged: (bool? value) {
                      controller.showAllCategories.value = value ?? true;
                      if (controller.showAllCategories.value) {
                        controller.selectedCategories.clear();
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final categoryName = categories[index];
                        final isSelected = controller.selectedCategories.contains(categoryName);

                        return CheckboxListTile(
                          title: Text(
                            categoryName,
                            style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 14),
                          ),
                          value: isSelected,
                          activeColor: Colors.green,
                          enabled: !controller.showAllCategories.value,
                          onChanged: controller.showAllCategories.value
                              ? null
                              : (bool? value) {
                                  if (value == true) {
                                    controller.selectedCategories.add(categoryName);
                                  } else {
                                    controller.selectedCategories.remove(categoryName);
                                  }
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
                  controller.selectedCategories.clear();
                  controller.showAllCategories.value = true;
                  controller.saveSelectedCategories();
                },
                child: const Text(
                  "Clear",
                  style: TextStyle(fontFamily: fontMulishSemiBold, color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  controller.saveSelectedCategories();
                  Navigator.pop(context);
                },
                child: const Text(
                  "Apply",
                  style: TextStyle(fontFamily: fontMulishSemiBold, color: Colors.white),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildGlobalSearchList(mc.MenuController controller) {
    final allItems = <Map<String, dynamic>>[];
    final sourceCategories = controller.showAllCategories.value ? controller.menuData.keys : controller.selectedCategories;

    for (var category in sourceCategories) {
      allItems.addAll(controller.menuData[category]!);
    }

    final filtered = allItems.where((item) {
      final name = item['name'].toString().toLowerCase();
      return name.contains(controller.searchQuery.value);
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
        
        return Obx(() {
          // Re-fetch the item so we get reactive qty updates
          final reactiveItem = controller.menuData[category]!.firstWhere((e) => e['name'] == item['name']);
          final reactiveIndex = controller.menuData[category]!.indexOf(reactiveItem);
          final qty = reactiveItem['qty'] as int;
          
          return _buildMenuTile(controller, category, reactiveIndex, reactiveItem, qty);
        });
      },
    );
  }

  Widget _buildMenuTile(mc.MenuController controller, String category, int index, Map<String, dynamic> item, int qty) {
    return InkWell(
      onTap: () {
        controller.incrementQty(category, index);
      },
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
            title: Text(
              item['name'],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2d3436),
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
                      color: Colors.grey,
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
                      controller.incrementQty(category, index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // Absorb stray taps
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => controller.decrementQty(category, index),
                        ),
                        Text(
                          "$qty",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2d3436),
                            fontFamily: fontMulishSemiBold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () => controller.incrementQty(category, index),
                        ),
                      ],
                    ),
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
