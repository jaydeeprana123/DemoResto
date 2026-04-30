import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:demo/services/ai_order_service.dart';
import 'package:demo/services/restaurant_agent_service.dart';
import 'package:demo/models/agent_response.dart';

import 'CartPage.dart';
import 'MyWidgets/EditableTextField.dart';
import 'Styles/my_colors.dart';
import 'Styles/my_font.dart';

// ── Brand colours (shared across screens) ─────────────────────────────────
const _kNavy   = Color(0xFF1A3A5C);
const _kOrange = Color(0xFFf57c35);


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
  final bool isFromFinalBilling;

  const MenuPage({
    required this.onConfirm,
    required this.menuList,
    required this.tableName,
    required this.tableNameEditable,
    required this.showBilling,
    required this.isFromFinalBilling,
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

  // Voice AI
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;        // true while Agent is working
  bool _speechInitialized = false;   // init only once per session
  String _recognizedText = '';       // full display text (accumulated + partial)
  String _accumulatedText = '';      // permanently committed text across restarts
  String _partialText = '';          // current session partial (not yet committed)
  bool _keepListening = false;       // user intent: keep going until Stop
  StateSetter? _sheetSetState;       // ref to sheet's setState for auto-restart
  // Agent layer — sits on top of AiOrderService
  final RestaurantAgentService _agentService = RestaurantAgentService();

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

  // ── Continuous listening ─────────────────────────────────────────────────

  /// Restarts the speech engine. Called automatically on pause (onStatus=done)
  /// or on error. Only runs while _keepListening is true.
  void _resumeListening() {
    if (!_keepListening || !mounted || _speech.isListening) return;

    _partialText = '';

    _speech.listen(
      onResult: (val) {
        if (!mounted) return;
        _partialText = val.recognizedWords;

        if (val.finalResult) {
          // Commit partial permanently to accumulated
          _accumulatedText = _accumulatedText.isEmpty
              ? _partialText
              : '$_accumulatedText $_partialText';
          _partialText = '';
        }

        // Display = accumulated + current partial
        final display = _accumulatedText.isEmpty
            ? _partialText
            : _partialText.isEmpty
                ? _accumulatedText
                : '$_accumulatedText $_partialText';

        _sheetSetState?.call(() {
          _recognizedText = display.trim();
        });
      },
      listenFor: const Duration(minutes: 5),
      // generous pauseFor — onStatus('done') will restart us anyway
      pauseFor: const Duration(seconds: 10),
      cancelOnError: false,
      partialResults: true,
      localeId: 'en_IN', // Indian English — better for mixed Hindi/Gujarati
    );

    _sheetSetState?.call(() => _isListening = true);
  }

  void _startVoiceOrder() async {
    // Reset all voice state
    _accumulatedText = '';
    _recognizedText = '';
    _partialText = '';
    _keepListening = false;
    _isListening = false;
    _isProcessing = false;
    _sheetSetState = null;

    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech error: $val');
          if (_keepListening && mounted) {
            Future.delayed(const Duration(milliseconds: 600), _resumeListening);
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          // Android fires 'done'/'notListening' after each pause.
          // Only restart if the USER has not pressed Stop.
          if (_keepListening &&
              mounted &&
              (status == 'done' || status == 'notListening')) {
            Future.delayed(const Duration(milliseconds: 300), _resumeListening);
          }
        },
      );
    }

    if (!_speechInitialized) {
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

            void startRecording() {
              _keepListening = true;
              _resumeListening();
            }

            void stopAndProcess() async {
              // Set flag FIRST so onStatus('done') won't restart
              _keepListening = false;
              await _speech.stop();
              // Use accumulated + any remaining partial
              final finalText = _recognizedText.trim();
              setSheetState(() {
                _isListening = false;
                _isProcessing = true;
              });
              await _processOrderAndClose(finalText, sheetContext);
              setSheetState(() => _isProcessing = false);
            }

            void cancel() async {
              _keepListening = false;
              await _speech.stop();
              setSheetState(() => _isListening = false);
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
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Mic icon with colour state
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 40,
                    color: _isListening ? Colors.red : Colors.grey.shade400,
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
                    _isListening
                        ? '🔴 Listening — speak items, quantities & remarks'
                        : _recognizedText.isNotEmpty
                            ? 'Tap Stop & Process to confirm'
                            : 'Tap Start, then speak your full order',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isListening
                          ? Colors.red.shade700
                          : Colors.grey.shade600,
                      fontFamily: fontMulishRegular,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live transcript
                  Container(
                    width: double.infinity,
                    constraints:
                        const BoxConstraints(minHeight: 64, maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.red.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isListening
                            ? Colors.red.shade200
                            : Colors.grey.shade300,
                        width: _isListening ? 1.5 : 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(
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
                            width: 16, height: 16,
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
                          onPressed: _isProcessing ? null : cancel,
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
                        child: _isProcessing
                            ? ElevatedButton.icon(
                                onPressed: null,
                                icon: const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                label: const Text('Processing…'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                              )
                            : _isListening
                            ? ElevatedButton.icon(
                                onPressed: stopAndProcess,
                                icon: const Icon(
                                    Icons.stop_circle_outlined, size: 20),
                                label: const Text('Stop & Process'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: startRecording,
                                icon: const Icon(Icons.mic, size: 20),
                                label: Text(
                                  _recognizedText.isEmpty
                                      ? 'Start'
                                      : 'Continue',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
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
      _keepListening = false;
      _sheetSetState = null;
      _speech.stop();
    });
  }

  Future<void> _processOrderAndClose(
    String text,
    BuildContext sheetContext,
  ) async {
    if (text.trim().isEmpty) {
      if (mounted && Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
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
      response = AgentResponse.retry('Order processing failed. Please try again.');
      debugPrint('[MenuPage] Agent error: $e');
    }

    // Close voice sheet
    if (mounted && Navigator.canPop(sheetContext)) Navigator.pop(sheetContext);
    if (!mounted) return;

    // ── Route based on agent decision ─────────────────────────────────────
    switch (response.action) {
      case AgentAction.auto:
        _applyOrderResults(response.items);
        final itemNames = response.items
            .map((r) => '${r.item['name']} ×${r.quantity}')
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Added: $itemNames'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
        // Save to Firestore history (fire and forget)
        _agentService.saveOrderToHistory(response.items).ignore();
        break;

      case AgentAction.suggest:
        _showSuggestSheet(response);
        break;

      case AgentAction.retry:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎤 ${response.message}'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Try Again',
            textColor: Colors.white,
            onPressed: _startVoiceOrder,
          ),
        ));
        break;
    }
  }

  /// Applies a confirmed list of OrderResults into the menuData quantities.
  void _applyOrderResults(List<OrderResult> results) {
    setState(() {
      for (final r in results) {
        final itemName = r.item['name'];
        for (final category in menuData.keys) {
          for (int i = 0; i < menuData[category]!.length; i++) {
            if (menuData[category]![i]['name'] == itemName) {
              menuData[category]![i]['qty'] += r.quantity;
              if (r.remarks.isNotEmpty) {
                menuData[category]![i]['remarks'] = r.remarks;
              }
            }
          }
        }
      }
    });
  }

  /// Shows the "Did you mean?" confirmation sheet (AgentAction.suggest).
  void _showSuggestSheet(AgentResponse response) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Icon(Icons.help_outline,
                      color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      response.message,
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Mulish SemiBold',
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(response.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontFamily: 'Mulish Regular',
                ),
              ),
              const SizedBox(height: 16),
              // Item chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: response.suggestions.map((r) {
                  return Chip(
                    label: Text(
                      '${r.item['name']} ×${r.quantity}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Mulish SemiBold',
                      ),
                    ),
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide(color: Colors.orange.shade200),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Let user try voice again
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          _startVoiceOrder,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('No, retry'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _applyOrderResults(response.suggestions);
                        _agentService
                            .saveOrderToHistory(response.suggestions)
                            .ignore();
                        final names = response.suggestions
                            .map((r) =>
                                '${r.item['name']} ×${r.quantity}')
                            .join(', ');
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text('✅ Added: $names'),
                          backgroundColor: Colors.green.shade700,
                          duration: const Duration(seconds: 4),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Yes, add these'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
                    const Icon(Icons.restaurant_menu, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    (widget.tableName.contains("Table") || !widget.tableNameEditable)
                        ? Text(
                            widget.tableName,
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
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _kOrange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
                  indicatorColor: _kOrange,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 13,
                  ),
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
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
                                          if (item['remarks'] != null && item['remarks'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                "Remarks: ${item['remarks']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange,
                                                  fontFamily: fontMulishSemiBold,
                                                ),
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
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
                                          if (item?['remarks'] != null && item!['remarks'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                "Remarks: ${item!['remarks']}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange,
                                                  fontFamily: fontMulishSemiBold,
                                                ),
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
                  if (widget.isFromFinalBilling) {
                    Navigator.pop(context, selectedItems);
                  } else {
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
                  }
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
