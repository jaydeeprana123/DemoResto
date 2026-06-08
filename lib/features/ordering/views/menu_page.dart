import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:demo/services/sarvam_stt_service.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/restaurant_agent_service.dart';
import 'package:demo/models/agent_response.dart';

import 'package:demo/core/utils/table_name_utils.dart';
import 'package:demo/features/ordering/views/cart_page.dart';
import 'package:demo/features/ordering/views/final_billing_view.dart';
import 'package:demo/features/ordering/utils/menu_item_variants.dart';
import 'package:demo/MyWidgets/EditableTextField.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';

// ── Brand colours (shared across screens) ─────────────────────────────────
const _kNavy = Color(0xFF1A3A5C);
const _kOrange = Color(0xFFf57c35);
const _kCategoryInactive = Color(0xFFF3F8F9);

class MenuPage extends StatefulWidget {
  final Future<void> Function(
    List<Map<String, dynamic>> selectedItems,
    bool isBillPaid,
    String tableName,
    String overallRemarks, {
    bool fromBilling,
    bool fromFinalBilling,
  })
  onConfirm;
  final List<Map<String, dynamic>> menuList; // Passed from previous page
  final List<Map<String, dynamic>> initialItems;

  /// Items already on the table (previous rounds) — shown read-only in cart/billing.
  final List<Map<String, dynamic>> pastItems;
  final String tableName;
  final bool tableNameEditable;
  final bool showBilling;
  final bool isFromFinalBilling;

  /// Clears dine-in table items or deletes a take-away order (no transaction).
  final Future<void> Function(String tableName)? onDeleteTable;

  const MenuPage({
    required this.onConfirm,
    required this.menuList,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    required this.isFromFinalBilling,
    this.onDeleteTable,
    this.initialItems = const [],
    this.pastItems = const [],
    Key? key,
  }) : super(key: key);

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late Map<String, List<Map<String, dynamic>>> menuData;
  late List<Map<String, dynamic>> _pastItems;
  late TextEditingController tableNameController;

  ///Serach
  TextEditingController searchController = TextEditingController();
  bool _showSearch = false;
  String searchQuery = '';
  bool isNameEdit = false;
  // Multiple category selection
  Set<String> selectedCategories = {};
  bool showAllCategories = true; // Track if "All" is selected
  int _selectedCategoryIndex = 0;

  // Voice AI — Sarvam STT
  final SarvamSttService _sttService = SarvamSttService();
  bool _isRecording = false;
  bool _isTranscribing = false; // true while Sarvam API is working
  bool _isProcessing = false; // true while Agent is working
  String _recognizedText = ''; // transcript from Sarvam
  int _recordingSeconds = 0; // elapsed recording time
  Timer? _recordingTimer;
  double _currentAmplitude = 0.0; // for visual feedback
  Timer? _amplitudeTimer;
  StateSetter? _sheetSetState; // ref to sheet's setState
  // Agent layer — sits on top of AiOrderService
  final RestaurantAgentService _agentService = RestaurantAgentService();

  // Overall order remarks built up via Voice STT
  String _overallRemarks = '';

  @override
  void initState() {
    super.initState();
    tableNameController = TextEditingController(text: widget.tableName);
    tableNameController.addListener(_onTableNameChanged);
    _pastItems = widget.pastItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    // Group menuList by category; merge Half/Full pairs for display.
    menuData = {};
    final normalizedMenu = MenuItemVariants.normalizeMenuList(widget.menuList);

    for (var item in normalizedMenu) {
      final category = item['category'] as String;
      menuData[category] ??= [];
      menuData[category]!.add(item);
    }

    // Pre-fill quantities from initialItems if any
    for (var category in menuData.keys) {
      for (var item in menuData[category]!) {
        if (MenuItemVariants.hasVariants(item)) {
          for (final raw in item['variants'] as List) {
            final variant = raw as Map<String, dynamic>;
            final existingItem = widget.initialItems.firstWhere(
              (e) => e['name'] == variant['name'],
              orElse: () => {},
            );
            if (existingItem.isNotEmpty) {
              variant['qty'] = existingItem['qty'];
            }
          }
        } else {
          final existingItem = widget.initialItems.firstWhere(
            (e) => e['name'] == item['name'],
            orElse: () => {},
          );
          if (existingItem.isNotEmpty) {
            item['qty'] = existingItem['qty'];
          }
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

  void _onMenuItemAdd(String category, int index) {
    final item = menuData[category]![index];
    if (MenuItemVariants.hasVariants(item)) {
      _showHalfFullPicker(category, index, forDecrement: false);
      return;
    }
    incrementQty(category, index);
  }

  void _onMenuItemRemove(String category, int index) {
    final item = menuData[category]![index];
    if (!MenuItemVariants.hasVariants(item)) {
      decrementQty(category, index);
      return;
    }

    final withQty = (item['variants'] as List)
        .cast<Map<String, dynamic>>()
        .where((v) => (v['qty'] as int? ?? 0) > 0)
        .toList();
    if (withQty.isEmpty) return;
    if (withQty.length == 1) {
      setState(() {
        withQty.first['qty'] = (withQty.first['qty'] as int) - 1;
      });
      return;
    }
    _showHalfFullPicker(category, index, forDecrement: true);
  }

  Future<void> _showHalfFullPicker(
    String category,
    int index, {
    required bool forDecrement,
  }) async {
    final item = menuData[category]![index];
    final variants = MenuItemVariants.variantsOf(item);
    final displayName = MenuItemVariants.displayName(item);

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          displayName,
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 17,
            color: Color(0xFF1A3A5C),
          ),
        ),
        content: Text(
          forDecrement ? 'Remove which size?' : 'Select Half or Full',
          style: TextStyle(
            fontFamily: fontMulishRegular,
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          for (final variant in variants)
            if (!forDecrement || (variant['qty'] as int? ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: forDecrement
                          ? Colors.red.shade700
                          : _kNavy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(ctx, variant['label']?.toString()),
                    child: Text(
                      forDecrement
                          ? '${variant['label']} '
                                '(${variant['qty']}) — Remove 1'
                          : '${variant['label']} — '
                                '₹${(variant['price'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: fontMulishBold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    setState(() {
      for (final raw in item['variants'] as List) {
        final variant = raw as Map<String, dynamic>;
        if (variant['label']?.toString() != choice) continue;
        final current = variant['qty'] as int? ?? 0;
        if (forDecrement) {
          if (current > 0) variant['qty'] = current - 1;
        } else {
          variant['qty'] = current + 1;
        }
        break;
      }
    });
  }

  List<String> get _visibleCategories {
    if (showAllCategories) return menuData.keys.toList();
    return menuData.keys
        .where((category) => selectedCategories.contains(category))
        .toList();
  }

  void _selectCategory(int index) {
    setState(() => _selectedCategoryIndex = index);
  }

  Widget _buildCategorySidebar(List<String> categories, int activeIndex) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final sidebarWidth = kIsWeb ? 132.0 : 108.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: _kCategoryInactive,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: ListView.builder(
        itemCount: categories.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = index == activeIndex;

          return Material(
            color: isActive ? _kNavy : _kCategoryInactive,
            child: InkWell(
              onTap: () => _selectCategory(index),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? _kNavy
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Text(
                  category,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontFamily: fontMulishBold,
                    letterSpacing: 0.3,
                    color: isActive
                        ? Colors.white
                        : _kNavy.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItemsList(String category) {
    final items = menuData[category] ?? [];

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) => _buildMenuItem(category, index),
    );
  }

  Widget _buildSidebarMenuLayout() {
    final categories = _visibleCategories;

    if (categories.isEmpty) {
      return Center(
        child: Text(
          'No categories selected.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontFamily: fontMulishRegular,
          ),
        ),
      );
    }

    if (_selectedCategoryIndex >= categories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCategoryIndex = 0);
      });
    }

    final activeIndex = _selectedCategoryIndex.clamp(0, categories.length - 1);
    final activeCategory = categories[activeIndex];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySidebar(categories, activeIndex),
        Expanded(child: _buildMenuItemsList(activeCategory)),
      ],
    );
  }

  // ── Sarvam STT Recording ─────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) async {
      if (!_isRecording || !mounted) return;
      final amp = await _sttService.getAmplitude();
      // Normalize from dBFS (-160..0) to 0..1
      final normalized = ((amp + 50) / 50).clamp(0.0, 1.0);
      _sheetSetState?.call(() => _currentAmplitude = normalized);
    });
  }

  void _startVoiceOrder() async {
    // Reset all voice state
    _recognizedText = '';
    _isRecording = false;
    _isTranscribing = false;
    _isProcessing = false;
    _recordingSeconds = 0;
    _currentAmplitude = 0.0;
    _sheetSetState = null;
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();

    // Check mic permission
    final hasPerms = await _sttService.hasPermission();
    if (!hasPerms) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            _sheetSetState = setSheetState;

            void startRecording() async {
              // Voice recording not supported on web
              if (kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎤 Voice ordering requires the mobile app.'),
                    backgroundColor: Color(0xFF1A3A5C),
                  ),
                );
                return;
              }
              final started = await _sttService.startRecording();
              if (!started) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to start recording.')),
                  );
                }
                return;
              }
              setSheetState(() {
                _isRecording = true;
                _recordingSeconds = 0;
                _currentAmplitude = 0.0;
              });

              // Timer for elapsed seconds
              _recordingTimer?.cancel();
              _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                if (!_isRecording || !mounted) return;
                _sheetSetState?.call(() => _recordingSeconds++);
              });

              // Amplitude polling for visual feedback
              _startAmplitudePolling();
            }

            void stopAndProcess() async {
              // Stop timers
              _recordingTimer?.cancel();
              _amplitudeTimer?.cancel();

              setSheetState(() {
                _isRecording = false;
                _isTranscribing = true;
              });

              // Stop recording & transcribe via Sarvam AI
              final transcript = await _sttService.stopAndTranscribe();

              if (transcript == null || transcript.trim().isEmpty) {
                setSheetState(() => _isTranscribing = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not recognise speech. Please try again.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              setSheetState(() {
                _recognizedText = transcript;
                _isTranscribing = false;
                _isProcessing = true;
              });

              await _processOrderAndClose(transcript, sheetContext);
              if (mounted) setSheetState(() => _isProcessing = false);
            }

            void cancel() async {
              _recordingTimer?.cancel();
              _amplitudeTimer?.cancel();
              await _sttService.cancelRecording();
              setSheetState(() {
                _isRecording = false;
                _isTranscribing = false;
              });
              if (Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
            }

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
                      if (_isRecording)
                        Container(
                          width: 56 + (_currentAmplitude * 20),
                          height: 56 + (_currentAmplitude * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(
                              alpha: 0.15 + _currentAmplitude * 0.15,
                            ),
                          ),
                        ),
                      Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        size: 40,
                        color: _isRecording ? Colors.red : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title + subtitle
                  Text(
                    'Voice Order',
                    style: TextStyle(
                      fontSize: 17,
                      fontFamily: fontMulishBold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording
                        ? '🔴 Recording ${_formatDuration(_recordingSeconds)} — speak your order'
                        : _isTranscribing
                        ? '⏳ Transcribing with Sarvam AI…'
                        : _recognizedText.isNotEmpty
                        ? 'Transcript ready'
                        : 'Tap Start, then speak your full order',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isRecording
                          ? Colors.red.shade700
                          : _isTranscribing
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Powered by Sarvam badge
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
                      color: _isRecording
                          ? Colors.red.shade50
                          : _isTranscribing
                          ? Colors.blue.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isRecording
                            ? Colors.red.shade200
                            : _isTranscribing
                            ? Colors.blue.shade200
                            : Colors.grey.shade300,
                        width: _isRecording || _isTranscribing ? 1.5 : 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: _isRecording
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Simple amplitude bars
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(7, (i) {
                                      final barHeight =
                                          8.0 +
                                          (_currentAmplitude *
                                              24 *
                                              (i.isEven ? 1.0 : 0.6));
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        width: 4,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade400,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
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
                          : _isTranscribing
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
                              _recognizedText.isEmpty
                                  ? 'e.g. "do chicken tikka rice aur teen malai tikka less spicy"'
                                  : _recognizedText,
                              style: TextStyle(
                                fontSize: 13,
                                color: _recognizedText.isEmpty
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                                fontFamily: fontMulishRegular,
                                fontStyle: _recognizedText.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Processing indicator
                  if (_isProcessing)
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

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isProcessing || _isTranscribing)
                              ? null
                              : cancel,
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
                        child: (_isProcessing || _isTranscribing)
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
                                  _isTranscribing
                                      ? 'Transcribing…'
                                      : 'Processing…',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isTranscribing
                                      ? Colors.blue.shade600
                                      : Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                              )
                            : _isRecording
                            ? ElevatedButton.icon(
                                onPressed: stopAndProcess,
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 20,
                                ),
                                label: const Text('Stop & Process'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: startRecording,
                                icon: const Icon(Icons.mic, size: 20),
                                label: Text(
                                  _recognizedText.isEmpty ? 'Start' : 'Retry',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
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
      },
    ).whenComplete(() {
      _recordingTimer?.cancel();
      _amplitudeTimer?.cancel();
      _sheetSetState = null;
      _sttService.cancelRecording();
    });
  }

  Future<void> _processOrderAndClose(
    String text,
    BuildContext sheetContext,
  ) async {
    if (text.trim().isEmpty) {
      if (mounted && Navigator.canPop(sheetContext))
        Navigator.pop(sheetContext);
      return;
    }

    if (!mounted) return;

    // Collect all menu items for the agent
    final List<Map<String, dynamic>> allItems = [];
    menuData.forEach((_, items) => allItems.addAll(items));

    late AgentResponse response;
    try {
      response = await _agentService.handleInput(
        userText: text,
        menuItems: allItems,
      );
    } catch (e) {
      response = AgentResponse.retry(
        'Order processing failed. Please try again.',
      );
      debugPrint('[MenuPage] Agent error: $e');
    }

    // Close voice sheet
    if (mounted && Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
    if (!mounted) return;

    // ── Route based on agent decision ─────────────────────────────────────
    switch (response.action) {
      case AgentAction.auto:
        _showVoiceOrderDialog(
          items: response.items,
          title: 'Voice Order Recognised',
          isSuggestion: false,
          transcript: text,
        );
        break;

      case AgentAction.suggest:
        _showVoiceOrderDialog(
          items: response.suggestions,
          title: response.message,
          isSuggestion: true,
          confidence: response.confidence,
          transcript: text,
        );
        break;

      case AgentAction.retry:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎤 ${response.message}'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: _startVoiceOrder,
            ),
          ),
        );
        break;
    }
  }

  /// Applies a confirmed list of OrderResults into the menuData quantities.
  void _applyOrderResults(List<OrderResult> results) {
    setState(() {
      for (final r in results) {
        final itemName = r.item['name'];
        for (final category in menuData.keys) {
          for (final item in menuData[category]!) {
            MenuItemVariants.applyOrderToItem(
              item,
              itemName,
              r.quantity,
              remarks: r.remarks,
            );
          }
        }
      }
    });
  }

  /// Large dialog that shows all voice-recognised items with remove buttons
  /// and editable remarks fields per item.
  void _showVoiceOrderDialog({
    required List<OrderResult> items,
    required String title,
    required bool isSuggestion,
    double confidence = 1.0,
    String transcript = '',
  }) {
    if (items.isEmpty) return;

    // Mutable copy — user can remove items before confirming
    final editableItems = List<OrderResult>.from(items);
    // One TextEditingController per item — pre-filled with AI-extracted remarks
    final remarkControllers = editableItems
        .map((r) => TextEditingController(text: r.remarks))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                    decoration: BoxDecoration(
                      color: isSuggestion
                          ? Colors.orange.shade700
                          : const Color(0xFF1A3A5C),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
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
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: fontMulishBold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Confidence badge (only for suggestions)
                  if (isSuggestion)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.shade50,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Text(
                        'AI Confidence: ${(confidence * 100).toStringAsFixed(0)}%  •  Review items below',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontFamily: fontMulishRegular,
                        ),
                      ),
                    ),

                  // ── Item list ─────────────────────────────────────────────
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: editableItems.isEmpty
                        ? Padding(
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
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: editableItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final r = editableItems[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: isSuggestion
                                        ? Colors.orange.shade200
                                        : const Color(
                                            0xFF1A3A5C,
                                          ).withValues(alpha: 0.25),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Item colour dot
                                        Container(
                                          margin: const EdgeInsets.only(top: 3),
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSuggestion
                                                ? Colors.orange.shade600
                                                : const Color(0xFFf57c35),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Name + qty
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      r.item['name']
                                                              as String? ??
                                                          '',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            fontMulishBold,
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  // Quantity badge
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isSuggestion
                                                          ? Colors
                                                                .orange
                                                                .shade50
                                                          : const Color(
                                                              0xFF1A3A5C,
                                                            ).withValues(
                                                              alpha: 0.08,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: isSuggestion
                                                            ? Colors
                                                                  .orange
                                                                  .shade300
                                                            : const Color(
                                                                0xFF1A3A5C,
                                                              ).withValues(
                                                                alpha: 0.3,
                                                              ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Qty: ${r.quantity}',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            fontMulishBold,
                                                        fontSize: 12,
                                                        color: isSuggestion
                                                            ? Colors
                                                                  .orange
                                                                  .shade800
                                                            : const Color(
                                                                0xFF1A3A5C,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Remove button
                                        GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              remarkControllers[index]
                                                  .dispose();
                                              editableItems.removeAt(index);
                                              remarkControllers.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
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
                                    // ── Remarks field (always visible in dialog) ─
                                    // const SizedBox(height: 8),
                                    // TextField(
                                    //   controller: remarkControllers[index],
                                    //   decoration: InputDecoration(
                                    //     hintText: 'e.g. less spicy, no onion, parcel…',
                                    //     hintStyle: TextStyle(
                                    //       fontSize: 12,
                                    //       color: Colors.grey.shade400,
                                    //       fontStyle: FontStyle.italic,
                                    //     ),
                                    //     isDense: true,
                                    //     prefixIcon: Icon(Icons.notes_outlined,
                                    //         size: 16, color: Colors.orange.shade600),
                                    //     border: OutlineInputBorder(
                                    //       borderRadius: BorderRadius.circular(8),
                                    //       borderSide: BorderSide(color: Colors.grey.shade300),
                                    //     ),
                                    //     enabledBorder: OutlineInputBorder(
                                    //       borderRadius: BorderRadius.circular(8),
                                    //       borderSide: BorderSide(color: Colors.grey.shade300),
                                    //     ),
                                    //     focusedBorder: OutlineInputBorder(
                                    //       borderRadius: BorderRadius.circular(8),
                                    //       borderSide: BorderSide(
                                    //           color: Colors.orange.shade400, width: 1.5),
                                    //     ),
                                    //     contentPadding: const EdgeInsets.symmetric(
                                    //         horizontal: 10, vertical: 8),
                                    //     filled: true,
                                    //     fillColor: Colors.orange.shade50,
                                    //   ),
                                    //   style: TextStyle(
                                    //     fontSize: 12,
                                    //     color: Colors.orange.shade800,
                                    //     fontFamily: fontMulishRegular,
                                    //   ),
                                    //   maxLines: 1,
                                    // ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // ── Footer buttons ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Cancel / Retry
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                _startVoiceOrder,
                              );
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Confirm (disabled if no items left)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: editableItems.isEmpty
                                ? null
                                : () {
                                    final updated = List.generate(
                                      editableItems.length,
                                      (i) => OrderResult(
                                        item: editableItems[i].item,
                                        quantity: editableItems[i].quantity,
                                        remarks: remarkControllers[i].text
                                            .trim(),
                                      ),
                                    );
                                    if (transcript.isNotEmpty) {
                                      if (_overallRemarks.isNotEmpty) {
                                        _overallRemarks += '\n';
                                      }
                                      _overallRemarks += transcript;
                                    }

                                    Navigator.pop(dialogCtx);
                                    _applyOrderResults(updated);
                                    _agentService
                                        .saveOrderToHistory(updated)
                                        .ignore();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ ${updated.length} item(s) added to cart',
                                        ),
                                        backgroundColor: Colors.green.shade700,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  },

                            icon: const Icon(Icons.check, size: 18),
                            label: Text(
                              editableItems.isEmpty
                                  ? 'Nothing to add'
                                  : 'Add to Cart',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final c in remarkControllers) c.dispose();
    });
  }

  // ── Menu item card helper ────────────────────────────────────────────────
  Widget _buildMenuItem(String category, int index) {
    final item = menuData[category]![index];
    final qty = MenuItemVariants.totalQty(item);
    final displayName = MenuItemVariants.displayName(item);

    return Container(
      margin: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      padding: const EdgeInsets.only(left: 14, top: 10, bottom: 10),
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
              onTap: () => _onMenuItemAdd(category, index),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
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
                        MenuItemVariants.priceLabel(item),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontFamily: fontMulishRegular,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (qty > 0)
                        Text(
                          ' x$qty',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kOrange,
                            fontFamily: fontMulishRegular,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          if (qty > 0)
            _stepperOnMinus(
              qty: qty,
              onDecrement: () => _onMenuItemRemove(category, index),
              onIncrement: () => _onMenuItemAdd(category, index),
            ),

          // qty == 0
          //     ? _addButton(onTap: () => _onMenuItemAdd(category, index))
          //     : _stepper(
          //         qty: qty,
          //         onDecrement: () => _onMenuItemRemove(category, index),
          //         onIncrement: () => _onMenuItemAdd(category, index),
          //       ),
        ],
      ),
    );
  }

  Widget _addButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kOrange, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            fontSize: 13,
            fontFamily: fontMulishBold,
            color: _kOrange,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _stepper({
    required int qty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 45,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: fontMulishBold,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 45,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(20),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperOnMinus({
    required int qty,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 45,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: fontMulishBold,
                color: Colors.white,
              ),
            ),
          ),
          // GestureDetector(
          //   onTap: onIncrement,
          //   child: Container(
          //     width: 45,
          //     height: 32,
          //     alignment: Alignment.center,
          //     decoration: const BoxDecoration(
          //       color: _kOrange,
          //       borderRadius: BorderRadius.horizontal(
          //         right: Radius.circular(20),
          //       ),
          //     ),
          //     child: const Icon(Icons.add, color: Colors.white, size: 16),
          //   ),
          // ),
        ],
      ),
    );
  }

  void _showRemarkEditSheet(String category, int index) {
    final item = menuData[category]![index];
    final ctrl = TextEditingController(
      text: (item['remarks'] ?? '').toString(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              style: const TextStyle(
                fontSize: 15,
                fontFamily: fontMulishBold,
                color: Color(0xFF1A3A5C),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. less spicy, no onion, kam tel…',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(
                  Icons.notes_outlined,
                  color: Colors.orange.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFf57c35),
                    width: 1.5,
                  ),
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
                  setState(() {
                    item['remarks'] = ctrl.text.trim();
                  });
                  Navigator.pop(ctx);
                  ctrl.dispose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Save Remark',
                  style: TextStyle(fontFamily: fontMulishBold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get totalItems {
    int total = 0;
    menuData.forEach((category, items) {
      for (var item in items) {
        total += MenuItemVariants.totalQty(item);
      }
    });
    return total;
  }

  double get totalPrice {
    double total = 0.0;
    menuData.forEach((category, items) {
      for (var item in items) {
        total += MenuItemVariants.totalLinePrice(item);
      }
    });
    return total;
  }

  bool get _useWebSideCart => kIsWeb && !widget.isFromFinalBilling;

  List<Map<String, dynamic>> _getSelectedItems() {
    final selectedItems = <Map<String, dynamic>>[];
    menuData.forEach((category, items) {
      for (final item in items) {
        selectedItems.addAll(MenuItemVariants.expandToCartLines(item));
      }
    });
    return selectedItems;
  }

  void _syncFromCart(List<Map<String, dynamic>> changedItems) {
    for (var category in menuData.keys) {
      for (var item in menuData[category]!) {
        MenuItemVariants.syncVariantQtyFromCart(item, changedItems);
      }
    }
    setState(() {});
  }

  void _onTableNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tableNameController.removeListener(_onTableNameChanged);
    tableNameController.dispose();
    searchController.dispose();
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _mergeItemLists(List<Map<String, dynamic>> lists) {
    final Map<String, Map<String, dynamic>> itemMap = {};

    for (final item in lists) {
      final key = '${item['name']}_${item['categoryId']}';
      if (itemMap.containsKey(key)) {
        itemMap[key]!['qty'] =
            (itemMap[key]!['qty'] as int) + (item['qty'] as int);
      } else {
        itemMap[key] = Map<String, dynamic>.from(item);
      }
    }

    return itemMap.values.toList();
  }

  List<Map<String, dynamic>> _mergeAllForBilling() {
    return _mergeItemLists([..._pastItems, ..._getSelectedItems()]);
  }

  bool get _hasOrderItems =>
      _pastItems.isNotEmpty || _getSelectedItems().isNotEmpty;

  bool get _isTakeAwayTable =>
      isTakeAwayOrderName(tableNameController.text.trim());

  bool get _canEditTableName => !widget.isFromFinalBilling;

  bool get _canDeleteTable =>
      !widget.isFromFinalBilling &&
      !isNameEdit &&
      widget.onDeleteTable != null &&
      (_pastItems.isNotEmpty ||
          _hasOrderItems ||
          (_isTakeAwayTable && widget.tableNameEditable));

  Future<void> _confirmDeleteTable() async {
    if (widget.onDeleteTable == null) return;

    final tableName = tableNameController.text.trim();
    final isTakeAway = _isTakeAwayTable;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isTakeAway ? 'Delete take away order?' : 'Clear table items?',
          style: const TextStyle(
            fontFamily: fontMulishBold,
            fontSize: 17,
            color: _kNavy,
          ),
        ),
        content: Text(
          isTakeAway
              ? 'All items on "$tableName" will be removed and the order will be deleted. No bill will be created.'
              : 'All items on "$tableName" will be removed. No bill will be created.',
          style: TextStyle(
            fontFamily: fontMulishRegular,
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isTakeAway ? 'Delete' : 'Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.onDeleteTable!(tableName);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _openFinalBilling() async {
    final merged = _mergeAllForBilling();
    if (merged.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add items before billing')));
      return;
    }

    final confirmedItems = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => FinalBillingView(
          menuData: merged,
          totalMenuList: widget.menuList,
          tableName: tableNameController.text.trim(),
          onConfirm: (_) {},
        ),
      ),
    );

    if (!mounted || confirmedItems == null) return;

    await widget.onConfirm(
      confirmedItems,
      false,
      tableNameController.text.trim(),
      _overallRemarks,
      fromFinalBilling: true,
    );

    if (mounted) Navigator.pop(context);
  }

  void _openCartPage() {
    final selectedItems = _getSelectedItems();

    if (widget.isFromFinalBilling) {
      Navigator.pop(context, selectedItems);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(
          tableName: tableNameController.text,
          nameController: tableNameController,
          tableNameEditable: _canEditTableName,
          menuData: selectedItems,
          pastItems: _pastItems,
          fullMenu: widget.menuList,
          overallRemarks: _overallRemarks,
          onConfirm: widget.onConfirm,
          showBilling: widget.showBilling,
        ),
      ),
    ).then((onValue) {
      if (onValue != null) {
        _syncFromCart(List<Map<String, dynamic>>.from(onValue as List));
      }
    });
  }

  Widget _buildWebCartPlaceholder() {
    return ColoredBox(
      color: const Color(0xFFF5F6FA),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Cart',
              style: TextStyle(
                fontFamily: fontMulishBold,
                fontSize: 18,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select items from the menu\nto see them here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontFamily: fontMulishRegular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSideCart() {
    final selectedItems = _getSelectedItems();
    if (selectedItems.isEmpty && _pastItems.isEmpty) {
      return _buildWebCartPlaceholder();
    }

    return CartPage(
      embedded: true,
      tableName: tableNameController.text,
      nameController: tableNameController,
      tableNameEditable: _canEditTableName,
      menuData: selectedItems,
      pastItems: _pastItems,
      fullMenu: widget.menuList,
      overallRemarks: _overallRemarks,
      onConfirm: widget.onConfirm,
      showBilling: widget.showBilling,
      onCartUpdated: _syncFromCart,
    );
  }

  Widget _buildMenuBodyContent() {
    return Column(
      children: [
        Expanded(
          child: _showSearch
              ? _buildGlobalSearchList()
              : _buildSidebarMenuLayout(),
        ),
        if (!_useWebSideCart && _hasOrderItems)
          InkWell(
            onTap: _openCartPage,
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
                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);
  static const _green = Color(0xFF4CAF50);
  static const _bg = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _showSearch
            ? TextField(
                controller: searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
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
                  // const Icon(Icons.restaurant_menu, color: Colors.white70, size: 20),
                  // const SizedBox(width: 8),
                  !_canEditTableName
                      ? Text(
                          tableNameController.text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: fontMulishBold,
                            color: Colors.white,
                          ),
                        )
                      : Expanded(
                          child: EditableTextField(
                            controller: tableNameController,
                            onEditingChanged: (value) {
                              setState(() => isNameEdit = value);
                            },
                          ),
                        ),
                ],
              ),

        actions: [
          if (_canDeleteTable)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              onPressed: _confirmDeleteTable,
              tooltip: _isTakeAwayTable ? 'Delete order' : 'Clear table',
            ),
          if (!isNameEdit &&
              _hasOrderItems &&
              !widget.showBilling &&
              !widget.isFromFinalBilling)
            IconButton(
              icon: const Icon(
                Icons.receipt_long_outlined,
                color: Colors.white,
              ),
              onPressed: _openFinalBilling,
              tooltip: 'Billing',
            ),
          if (!isNameEdit)
            IconButton(
              icon: const Icon(Icons.mic, color: Colors.redAccent),
              onPressed: _startVoiceOrder,
              tooltip: "Voice Order",
            ),
          if (!isNameEdit)
            IconButton(
              icon: Icon(
                _showSearch ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                if (_showSearch) {
                  searchQuery = '';
                  searchController.clear();
                }
                _showSearch = !_showSearch;
                setState(() {});
              },
            ),
          if (!isNameEdit)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
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
                        color: _kOrange,
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
      ),
      body: _useWebSideCart
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildMenuBodyContent()),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: _buildWebSideCart(),
                  ),
                ),
              ],
            )
          : _buildMenuBodyContent(),
      // floatingActionButton: !kIsWeb &&
      //         !widget.isFromFinalBilling &&
      //         _hasOrderItems
      //     ? FloatingActionButton.extended(
      //         backgroundColor: _kNavy,
      //         foregroundColor: Colors.white,
      //         icon: const Icon(Icons.receipt_long_outlined, size: 22),
      //         label: const Text(
      //           'Billing',
      //           style: TextStyle(
      //             fontFamily: fontMulishSemiBold,
      //             fontSize: 14,
      //           ),
      //         ),
      //         onPressed: _openFinalBilling,
      //       )
      //     : null,
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

                    setState(() {
                      _selectedCategoryIndex = 0;
                    });
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
                    setState(() {
                      _selectedCategoryIndex = 0;
                    });
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

    setState(() {
      _selectedCategoryIndex = 0;
    });
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
      final displayName = MenuItemVariants.displayName(item).toLowerCase();
      if (displayName.contains(searchQuery)) return true;
      if (MenuItemVariants.hasVariants(item)) {
        return MenuItemVariants.variantsOf(
          item,
        ).any((v) => v['name'].toString().toLowerCase().contains(searchQuery));
      }
      return false;
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
        final category = item['category'] as String;
        final itemIndex = menuData[category]!.indexWhere(
          (e) => e['name'] == item['name'],
        );
        if (itemIndex < 0) return const SizedBox.shrink();
        return _buildMenuItem(category, itemIndex);
      },
    );
  }
}
