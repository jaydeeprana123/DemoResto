import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/core/services/restaurant_session.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:demo/core/utils/table_name_utils.dart';
import 'package:demo/core/utils/zomato_order_utils.dart';
import 'package:demo/features/menu_setup/services/menu_cache_service.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:demo/features/kitchen/services/kitchen_settings.dart';
import 'package:demo/features/kitchen/services/kitchen_menu_filter.dart';
import 'package:demo/features/transactions/services/reverse_billing_service.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:demo/features/tables/widgets/order_item_row.dart';
import 'package:demo/features/zomato/widgets/zomato_order_card_body.dart';
import 'package:demo/features/zomato/repositories/zomato_orders_repository.dart';
import 'package:demo/features/zomato/widgets/zomato_order_progress_dialog.dart';
import 'package:demo/models/GroupOrder.dart';

class KitchenOrdersListView extends StatefulWidget {
  /// When false (e.g. another bottom-nav tab is selected), order bells stay silent.
  final bool isTabActive;

  const KitchenOrdersListView({super.key, this.isTabActive = true});

  @override
  State<KitchenOrdersListView> createState() => _KitchenOrdersListViewState();
}

class _KitchenOrdersListViewState extends State<KitchenOrdersListView>
    with WidgetsBindingObserver {
  final AudioPlayer audioPlayer = AudioPlayer();
  // Separate player for the update tone so its faster double-ring pattern
  // doesn't clash with the single new-order ring.
  final AudioPlayer updateAudioPlayer = AudioPlayer();
  // Distinct tone when an order/table disappears from the kitchen list.
  final AudioPlayer deleteAudioPlayer = AudioPlayer();
  DateTime? _lastDeleteSoundAt;
  Set<String> previousKeys = {};
  // Snapshot of each group's content (name + qty + remarks) so we can detect
  // quantity changes / newly added items even when the group key stays the same.
  Map<String, String> _previousSignatures = {};
  // Doc ids that already existed last build, used to tell a brand-new table
  // apart from an update to an already-available table.
  Set<String> _previousDocIds = {};
  Map<String, TableGroup> _previousKeyToGroup = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tablesSub;
  final ValueNotifier<int> _minuteTick = ValueNotifier(0);
  bool _kitchenStreamReady = false;

  /// True when the kitchen list was last shown empty (no orders to display).
  bool _wasKitchenEmpty = false;
  List<TableGroup> _lastUpdatedGroups = [];
  List<TableGroup> _displayFilteredGroups = [];
  List<KitchenTableCard> _displayTableCards = [];
  int? blinkingGroupKey;
  // Color used for the currently blinking card: green for a new order,
  // yellow for an update (quantity changed / item added on existing table).
  Color _blinkColor = Colors.lightGreenAccent.shade100;
  Timer? _timer;
  final TableItemSelectionController _itemSelection =
      TableItemSelectionController();

  static final Color _newOrderBlinkColor = Colors.lightGreenAccent.shade100;
  static final Color _updateBlinkColor = Colors.yellow.shade300;
  static final Color _delayedItemBackground = Color(0xFFFFEBEE); // light red
  static final Color _delayedItemBlinkBackground = Color(0xFFFFCDD2);
  static const int _delayThresholdMinutes = 15;
  static const int _delayedBlinkPulseCount = 7;

  Set<int> _delayedBlinkGroupKeys = {};
  bool _delayedBlinkHighlight = false;
  Timer? _delayedBlinkTimer;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  bool _isOrderDelayed(DateTime time) =>
      DateTime.now().difference(time).inMinutes > _delayThresholdMinutes;

  bool _isDelayedGroupBlinking(TableGroup group) =>
      _delayedBlinkGroupKeys.contains(group.key.hashCode) &&
      _delayedBlinkHighlight;

  Iterable<TableGroup> get _visibleKitchenGroups => _showTableAllOrders
      ? _displayTableCards.expand((card) => card.batches)
      : _displayFilteredGroups;

  void _triggerDelayedBlinkIfNeeded() {
    final delayedKeys = _visibleKitchenGroups
        .where(
          (group) => _isOrderDelayed(
            DateTime.fromMillisecondsSinceEpoch(group.groupTime),
          ),
        )
        .map((group) => group.key.hashCode)
        .toSet();
    if (delayedKeys.isEmpty) return;
    _startDelayedBlinkAnimation(delayedKeys);
  }

  void _startDelayedBlinkAnimation(Set<int> groupKeyHashes) {
    _delayedBlinkTimer?.cancel();
    if (groupKeyHashes.isEmpty || !mounted) return;

    setState(() {
      _delayedBlinkGroupKeys = groupKeyHashes;
      _delayedBlinkHighlight = true;
    });

    var pulseCount = 0;
    _delayedBlinkTimer = Timer.periodic(const Duration(milliseconds: 450), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      pulseCount++;
      if (pulseCount >= _delayedBlinkPulseCount * 2) {
        timer.cancel();
        setState(() {
          _delayedBlinkGroupKeys.clear();
          _delayedBlinkHighlight = false;
        });
        return;
      }

      setState(() => _delayedBlinkHighlight = !_delayedBlinkHighlight);
    });
  }

  bool get _canRingBell {
    if (KitchenSettings.backgroundOrderRingtoneEnabled.value) {
      return _appLifecycleState != AppLifecycleState.detached;
    }
    return _appLifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _configureAudioPlayers() async {
    final allowBackground =
        KitchenSettings.backgroundOrderRingtoneEnabled.value;
    final context = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: allowBackground,
        contentType: AndroidContentType.sonification,
        usageType: allowBackground
            ? AndroidUsageType.alarm
            : AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    );

    try {
      await AudioPlayer.global.setAudioContext(context);
      await audioPlayer.setAudioContext(context);
      await updateAudioPlayer.setAudioContext(context);
      await deleteAudioPlayer.setAudioContext(context);
    } catch (_) {
      // ignore audio setup errors on unsupported platforms
    }
  }

  String _groupSignature(TableGroup group) {
    final parts =
        group.items
            .map((it) {
              final item = TableItemServed.asItemMap(it);
              if (item == null) return '';
              return '${item['name']}~${item['qty'] ?? 1}~${item['remarks']?.toString() ?? ''}~${item['isServed'] == true}';
            })
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort();
    return parts.join('|');
  }

  void _scheduleBlink({
    required String key,
    required Map<String, TableGroup> keyToGroup,
    required Set<String> currentKeys,
    required Map<String, String> currentSignatures,
    required Set<String> currentDocIds,
    required bool isUpdate,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final group = keyToGroup[key];
      final shouldPlaySound = group != null
          ? _shouldPlaySoundForGroup(group)
          : true;

      setState(() {
        previousKeys = currentKeys;
        _previousSignatures = currentSignatures;
        _previousDocIds = currentDocIds;
        _previousKeyToGroup = keyToGroup;
        blinkingGroupKey = key.hashCode;
        _blinkColor = isUpdate ? _updateBlinkColor : _newOrderBlinkColor;
      });

      if (shouldPlaySound && _canRingBell) {
        if (isUpdate) {
          _playUpdateSound();
        } else {
          _playNotificationSound();
        }
      }

      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (blinkingGroupKey == key.hashCode) {
          setState(() => blinkingGroupKey = null);
        }
      });
    });
  }

  // Multiple category selection
  Set<String> selectedCategories = {};
  Set<String> selectedMenuItems = {};
  bool showAllCategories = true; // Track if "All" is selected
  bool _useLegacyCategoryOnlyFilter = false;
  late final KitchenMenuFilter _menuFilter =
      KitchenMenuFilter(Get.find<MenuCacheService>());
  bool _showTableAllOrders = true;
  bool _showServeOrderScreen = false;

  /// 0 = active (unserved items), 1 = served items only
  int _kitchenOrderTabIndex = 0;

  /// 0 = All, 1 = Table (dine-in), 2 = Take Away, 3 = Zomato
  int _orderTypeFilterIndex = 0;
  bool _mobileLayoutIsGrid = false;

  void _onBackgroundRingtoneSettingChanged() {
    _configureAudioPlayers();
    if (!KitchenSettings.backgroundOrderRingtoneEnabled.value &&
        _appLifecycleState != AppLifecycleState.resumed) {
      _stopAllKitchenSounds();
    }
  }

  void _onKitchenSettingsChanged() {
    if (!mounted) return;
    final layoutChanged =
        _mobileLayoutIsGrid != KitchenSettings.mobileOrdersGridLayout.value;
    setState(() {
      _showTableAllOrders = KitchenSettings.showTableAllOrders.value == true;
      _showServeOrderScreen =
          KitchenSettings.showServeOrderScreen.value == true;
      _mobileLayoutIsGrid = KitchenSettings.mobileOrdersGridLayout.value;
      if (!_showServeOrderScreen) {
        _kitchenOrderTabIndex = 0;
        _itemSelection.cancel();
      }
      if (!layoutChanged) {
        _rebuildDisplayFromCache();
      }
    });
  }

  void _playNotificationSound() async {
    if (!_canRingBell) return;
    try {
      await audioPlayer.play(AssetSource('sounds/phone_bell.mp3'));
    } catch (e) {
      // ignore audio errors
    }
  }

  Future<bool> _hasDeleteBellAsset() async {
    try {
      await rootBundle.load('assets/sounds/delete_bell.mp3');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Distinct from new-order (phone_bell) and update (update_bell) rings.
  void _playDeleteSound() async {
    if (!_canRingBell) return;
    final now = DateTime.now();
    if (_lastDeleteSoundAt != null &&
        now.difference(_lastDeleteSoundAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastDeleteSoundAt = now;

    try {
      await deleteAudioPlayer.stop();
      await deleteAudioPlayer.setReleaseMode(ReleaseMode.stop);

      if (await _hasDeleteBellAsset()) {
        await deleteAudioPlayer.setPlaybackRate(1.0);
        await deleteAudioPlayer.play(AssetSource('sounds/delete_bell.mp3'));
      } else {
        // Slower update bell — clearly different tone without a separate file.
        await deleteAudioPlayer.setPlaybackRate(0.52);
        await deleteAudioPlayer.play(AssetSource('sounds/update_bell.mp3'));
        await deleteAudioPlayer.setPlaybackRate(1.0);
      }
    } catch (e) {
      // ignore audio errors
    }
  }

  bool _shouldPlaySoundForRemoval(
    Set<String> removedKeys,
    Set<String> removedDocIds,
  ) {
    if (showAllCategories || !_hasActiveCategoryFilter) {
      return removedKeys.isNotEmpty || removedDocIds.isNotEmpty;
    }

    for (final key in removedKeys) {
      final group = _previousKeyToGroup[key];
      if (group != null && _shouldPlaySoundForGroup(group)) return true;
    }

    for (final group in _previousKeyToGroup.values) {
      if (removedDocIds.contains(group.docId) &&
          _shouldPlaySoundForGroup(group)) {
        return true;
      }
    }

    return false;
  }

  void _notifyOrderRemoved({
    required Set<String> removedKeys,
    required Set<String> removedDocIds,
    required Set<String> currentKeys,
    required Map<String, String> currentSignatures,
    required Set<String> currentDocIds,
    required Map<String, TableGroup> keyToGroup,
  }) {
    final shouldPlay = _shouldPlaySoundForRemoval(removedKeys, removedDocIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        previousKeys = currentKeys;
        _previousSignatures = currentSignatures;
        _previousDocIds = currentDocIds;
        _previousKeyToGroup = keyToGroup;
      });
      if (shouldPlay && _canRingBell) _playDeleteSound();
    });
  }

  Future<void> _stopAllKitchenSounds() async {
    try {
      await audioPlayer.stop();
      await updateAudioPlayer.stop();
      await deleteAudioPlayer.stop();
    } catch (_) {
      // ignore audio errors
    }
  }

  // Distinct tone for order updates (quantity changed / item added on an
  // already-available table) so kitchen staff can tell it apart from a
  // brand-new order's ring.
  void _playUpdateSound() async {
    if (!_canRingBell) return;
    try {
      await updateAudioPlayer.stop();
      await updateAudioPlayer.play(AssetSource('sounds/update_bell.mp3'));
    } catch (e) {
      // ignore audio errors
    }
  }

  List<TableGroup> _reconstructGroups(
    String tableName,
    List<dynamic>? itemsFromDb, {
    required bool isPaid,
    required String docId,
    String? lastTransactionId,
    String? source,
    String? screenshotUrl,
    String? zomatoStatus,
    Timestamp? createdAt,
  }) {
    List<TableGroup> groups = [];
    if (itemsFromDb == null) itemsFromDb = const [];

    Map<int, List<Map<String, dynamic>>> groupMap = {};
    Map<int, Timestamp> groupTimeMap = {};

    for (final raw in itemsFromDb) {
      final itemMap = TableItemServed.asItemMap(raw);
      if (itemMap == null) continue;

      final int groupIndex = (itemMap['groupIndex'] is int)
          ? itemMap['groupIndex'] as int
          : 0;
      final Timestamp addedAt = (itemMap['addedAt'] is Timestamp)
          ? itemMap['addedAt'] as Timestamp
          : Timestamp.now();

      final normalized = Map<String, dynamic>.from(itemMap);
      normalized.remove('groupIndex');
      normalized.remove('addedAt');

      groupMap.putIfAbsent(groupIndex, () => []);
      groupMap[groupIndex]!.add(normalized);
      groupTimeMap[groupIndex] = addedAt;
    }

    groupMap.forEach((index, items) {
      if (items.isEmpty) return;
      final timestamp = groupTimeMap[index] ?? Timestamp.now();
      groups.add(
        TableGroup(
          tableName,
          items,
          timestamp.toDate().millisecondsSinceEpoch,
          key: '${tableName}_$index',
          docId: docId,
          isPaid: isPaid,
          groupIndex: index,
          lastTransactionId: lastTransactionId,
          source: source,
          screenshotUrl: screenshotUrl,
          zomatoStatus: zomatoStatus,
        ),
      );
    });

    if (groups.isEmpty &&
        ZomatoOrderUtils.isZomatoSource(source) &&
        (screenshotUrl?.isNotEmpty ?? false)) {
      final timestamp = createdAt ?? Timestamp.now();
      groups.add(
        TableGroup(
          tableName,
          const [],
          timestamp.toDate().millisecondsSinceEpoch,
          key: '${tableName}_zomato_0',
          docId: docId,
          isPaid: isPaid,
          groupIndex: 0,
          lastTransactionId: lastTransactionId,
          source: source,
          screenshotUrl: screenshotUrl,
          zomatoStatus: zomatoStatus,
        ),
      );
    }

    return groups;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (!KitchenSettings.backgroundOrderRingtoneEnabled.value &&
        state != AppLifecycleState.resumed) {
      _stopAllKitchenSounds();
    }
  }

  @override
  void didUpdateWidget(KitchenOrdersListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive &&
        !widget.isTabActive &&
        !KitchenSettings.backgroundOrderRingtoneEnabled.value) {
      _stopAllKitchenSounds();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureAudioPlayers();
    KitchenSettings.load().then((_) async {
      await Get.find<MenuCacheService>().ensureLoaded();
      _menuFilter.invalidate();
      if (mounted) {
        setState(() {
          _showTableAllOrders =
              KitchenSettings.showTableAllOrders.value == true;
          _showServeOrderScreen =
              KitchenSettings.showServeOrderScreen.value == true;
          _mobileLayoutIsGrid =
              KitchenSettings.mobileOrdersGridLayout.value == true;
          showAllCategories = KitchenSettings.showAllCategories;
          selectedCategories = Set<String>.from(
            KitchenSettings.selectedCategories,
          );
          selectedMenuItems = Set<String>.from(
            KitchenSettings.selectedMenuItems,
          );
          _useLegacyCategoryOnlyFilter =
              !showAllCategories &&
              selectedCategories.isNotEmpty &&
              selectedMenuItems.isEmpty;
          _orderTypeFilterIndex = KitchenSettings.orderTypeFilterIndex;
          _rebuildDisplayFromCache();
        });
      }
    });
    KitchenSettings.showTableAllOrders.addListener(_onKitchenSettingsChanged);
    KitchenSettings.showServeOrderScreen.addListener(_onKitchenSettingsChanged);
    KitchenSettings.mobileOrdersGridLayout.addListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.backgroundOrderRingtoneEnabled.addListener(
      _onBackgroundRingtoneSettingChanged,
    );
    _tablesSub = FirestorePaths.scoped('tables')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(_handleTablesSnapshot);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _minuteTick.value++;
      _triggerDelayedBlinkIfNeeded();
    });
  }

  void _rebuildDisplayFromCache() {
    final filtered = _applyKitchenDisplayFilters(_lastUpdatedGroups);
    _displayFilteredGroups = filtered;
    _displayTableCards = _mergeGroupsByTable(filtered);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _triggerDelayedBlinkIfNeeded();
    });
  }

  List<TableGroup> _applyKitchenDisplayFilters(List<TableGroup> groups) {
    final byCategory = _filterByCategories(groups);
    final byOrderType = _filterByOrderType(byCategory);
    if (!_showServeOrderScreen) {
      return _filterAllItems(byOrderType);
    }
    return _filterByServedStatus(
      byOrderType,
      servedOnly: _kitchenOrderTabIndex == 1,
    );
  }

  List<TableGroup> _filterByOrderType(List<TableGroup> groups) {
    if (_orderTypeFilterIndex == 0) return groups;
    if (_orderTypeFilterIndex == 3) {
      return groups.where((group) => group.isZomato).toList();
    }
    return groups.where((group) {
      if (group.isZomato) return false;
      final isTakeAway = isTakeAwayOrderName(group.tableName);
      if (_orderTypeFilterIndex == 1) {
        return isDiningTableName(group.tableName);
      }
      return isTakeAway;
    }).toList();
  }

  void _onOrderTypeFilterChanged(int? value) {
    if (value == null || value == _orderTypeFilterIndex) return;
    setState(() {
      _orderTypeFilterIndex = value;
      _itemSelection.cancel();
      _rebuildDisplayFromCache();
    });
    KitchenSettings.saveOrderTypeFilterIndex(value);
  }

  List<TableGroup> _filterAllItems(List<TableGroup> groups) {
    return groups
        .map((group) {
          if (group.isZomato) {
            if (ZomatoOrderUtils.isCompletedStatus(group.zomatoStatus)) {
              return null;
            }
            return group;
          }
          final filteredItems = group.items
              .asMap()
              .entries
              .where((entry) => TableItemServed.asItemMap(entry.value) != null)
              .map((entry) {
                final item = TableItemServed.asItemMap(entry.value)!;
                final copy = Map<String, dynamic>.from(item);
                copy['__itemIndex'] = item['__itemIndex'] as int? ?? entry.key;
                return copy;
              })
              .toList();

          if (filteredItems.isEmpty) return null;

          return TableGroup(
            group.tableName,
            filteredItems,
            group.groupTime,
            key: group.key,
            docId: group.docId,
            isPaid: group.isPaid,
            groupIndex: group.groupIndex,
            lastTransactionId: group.lastTransactionId,
            source: group.source,
            screenshotUrl: group.screenshotUrl,
            zomatoStatus: group.zomatoStatus,
          );
        })
        .whereType<TableGroup>()
        .toList();
  }

  void _onKitchenOrderTabChanged(int index) {
    if (_kitchenOrderTabIndex == index) return;
    setState(() {
      _kitchenOrderTabIndex = index;
      _itemSelection.cancel();
      _rebuildDisplayFromCache();
    });
  }

  List<TableGroup> _filterByServedStatus(
    List<TableGroup> groups, {
    required bool servedOnly,
  }) {
    return groups
        .map((group) {
          if (group.isZomato) {
            final completed = ZomatoOrderUtils.isCompletedStatus(
              group.zomatoStatus,
            );
            return servedOnly == completed ? group : null;
          }
          final filteredItems = group.items
              .asMap()
              .entries
              .where((entry) {
                final item = TableItemServed.asItemMap(entry.value);
                if (item == null) return false;
                final served = TableItemServed.isServed(item);
                return servedOnly ? served : !served;
              })
              .map((entry) {
                final item = TableItemServed.asItemMap(entry.value)!;
                final copy = Map<String, dynamic>.from(item);
                copy['__itemIndex'] = item['__itemIndex'] as int? ?? entry.key;
                return copy;
              })
              .toList();

          if (filteredItems.isEmpty) return null;

          return TableGroup(
            group.tableName,
            filteredItems,
            group.groupTime,
            key: group.key,
            docId: group.docId,
            isPaid: group.isPaid,
            groupIndex: group.groupIndex,
            lastTransactionId: group.lastTransactionId,
            source: group.source,
            screenshotUrl: group.screenshotUrl,
            zomatoStatus: group.zomatoStatus,
          );
        })
        .whereType<TableGroup>()
        .toList();
  }

  bool _sameGroupList(List<TableGroup> a, List<TableGroup> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key ||
          a[i].isPaid != b[i].isPaid ||
          _groupSignature(a[i]) != _groupSignature(b[i])) {
        return false;
      }
    }
    return true;
  }

  bool _sameTableCards(List<KitchenTableCard> a, List<KitchenTableCard> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].docId != b[i].docId || a[i].isPaid != b[i].isPaid) {
        return false;
      }
      if (a[i].batches.length != b[i].batches.length) return false;
      for (var j = 0; j < a[i].batches.length; j++) {
        if (a[i].batches[j].key != b[i].batches[j].key ||
            _groupSignature(a[i].batches[j]) !=
                _groupSignature(b[i].batches[j])) {
          return false;
        }
      }
    }
    return true;
  }

  void _handleTablesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;

    if (snapshot.docs.isEmpty) {
      _wasKitchenEmpty = true;
      if (previousKeys.isNotEmpty || _previousSignatures.isNotEmpty) {
        previousKeys = {};
        _previousSignatures = {};
        _previousDocIds = {};
        _previousKeyToGroup = {};
      }
      if (_displayFilteredGroups.isNotEmpty ||
          _displayTableCards.isNotEmpty ||
          !_kitchenStreamReady) {
        setState(() {
          _lastUpdatedGroups = [];
          _displayFilteredGroups = [];
          _displayTableCards = [];
          _kitchenStreamReady = true;
        });
      }
      return;
    }

    final updatedGroups = <TableGroup>[];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final tableName = (data['name'] ?? 'Unknown Table') as String;
      final isPaid = data['isPaid'] == true;
      final lastTransactionId = data['lastTransactionId']?.toString();
      final source = data['source']?.toString();
      final screenshotUrl = data['screenshotUrl']?.toString();
      final zomatoStatus = data['zomatoStatus']?.toString();
      final createdAt = data['createdAt'];
      final itemsFromDb = data.containsKey('items')
          ? (data['items'] as List<dynamic>?)
          : null;
      updatedGroups.addAll(
        _reconstructGroups(
          tableName,
          itemsFromDb,
          isPaid: isPaid,
          docId: doc.id,
          lastTransactionId: lastTransactionId,
          source: source,
          screenshotUrl: screenshotUrl,
          zomatoStatus: zomatoStatus,
          createdAt: createdAt is Timestamp ? createdAt : null,
        ),
      );
    }

    updatedGroups.sort((a, b) => a.groupTime.compareTo(b.groupTime));
    _lastUpdatedGroups = updatedGroups;

    final filteredGroups = _applyKitchenDisplayFilters(updatedGroups);
    final tableCards = _mergeGroupsByTable(filteredGroups);

    if (filteredGroups.isEmpty) {
      _wasKitchenEmpty = true;
    }

    final currentKeys = updatedGroups.map((g) => g.key).toSet();
    final currentSignatures = <String, String>{};
    final currentDocIds = <String>{};
    final keyToGroup = <String, TableGroup>{};
    for (final g in updatedGroups) {
      currentSignatures[g.key] = _groupSignature(g);
      currentDocIds.add(g.docId);
      keyToGroup[g.key] = g;
    }

    if (_previousSignatures.isEmpty && currentKeys.isNotEmpty) {
      if (_wasKitchenEmpty) {
        final newTableKeys = currentKeys
            .where((k) => !_previousDocIds.contains(keyToGroup[k]?.docId))
            .toList();
        final keyToBlink = newTableKeys.isNotEmpty
            ? newTableKeys.last
            : currentKeys.last;
        _scheduleBlink(
          key: keyToBlink,
          keyToGroup: keyToGroup,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          isUpdate: false,
        );
        _wasKitchenEmpty = false;
      } else {
        previousKeys = currentKeys;
        _previousSignatures = currentSignatures;
        _previousDocIds = currentDocIds;
        _previousKeyToGroup = keyToGroup;
      }
    } else if (_previousSignatures.isNotEmpty) {
      final addedKeys = currentKeys.difference(previousKeys);
      final removedKeys = previousKeys.difference(currentKeys);
      final removedDocIds = _previousDocIds.difference(currentDocIds);

      final changedKeys = currentKeys
          .where(
            (k) =>
                previousKeys.contains(k) &&
                _previousSignatures[k] != currentSignatures[k],
          )
          .toList();

      final newTableKeys = addedKeys
          .where((k) => !_previousDocIds.contains(keyToGroup[k]?.docId))
          .toList();

      final updateKeys = <String>[
        ...addedKeys.where(
          (k) => _previousDocIds.contains(keyToGroup[k]?.docId),
        ),
        ...changedKeys,
      ];

      if (newTableKeys.isNotEmpty) {
        _scheduleBlink(
          key: newTableKeys.last,
          keyToGroup: keyToGroup,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          isUpdate: false,
        );
      } else if (updateKeys.isNotEmpty) {
        _scheduleBlink(
          key: updateKeys.last,
          keyToGroup: keyToGroup,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          isUpdate: true,
        );
      } else if (removedKeys.isNotEmpty || removedDocIds.isNotEmpty) {
        _notifyOrderRemoved(
          removedKeys: removedKeys,
          removedDocIds: removedDocIds,
          currentKeys: currentKeys,
          currentSignatures: currentSignatures,
          currentDocIds: currentDocIds,
          keyToGroup: keyToGroup,
        );
      }
    }

    final displayChanged = _showTableAllOrders
        ? !_sameTableCards(_displayTableCards, tableCards)
        : !_sameGroupList(_displayFilteredGroups, filteredGroups);

    if (displayChanged || !_kitchenStreamReady) {
      setState(() {
        _displayFilteredGroups = filteredGroups;
        _displayTableCards = tableCards;
        _kitchenStreamReady = true;
      });
      _triggerDelayedBlinkIfNeeded();
    }

    if (filteredGroups.isNotEmpty) {
      _wasKitchenEmpty = false;
    }
  }

  String _emptyStateMessage() {
    final typeLabel = _orderTypeFilterIndex == 1
        ? 'table'
        : _orderTypeFilterIndex == 2
        ? 'take away'
        : _orderTypeFilterIndex == 3
        ? 'Zomato'
        : '';
    final typeSuffix = typeLabel.isEmpty ? '' : ' for $typeLabel orders';

    if (_kitchenOrderTabIndex == 1) {
      if (_hasActiveCategoryFilter) {
        return 'No served orders in selected categories$typeSuffix';
      }
      return 'No served orders$typeSuffix';
    }

    if (_hasActiveCategoryFilter) {
      return 'No orders in selected categories$typeSuffix';
    }
    return 'No orders found$typeSuffix';
  }

  Widget _buildKitchenEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasActiveCategoryFilter
                ? Icons.filter_list_off
                : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _emptyStateMessage(),
            style: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (_hasActiveCategoryFilter) ...[
            const SizedBox(height: 8),
            Text(
              selectedCategories.isNotEmpty
                  ? "Selected: ${selectedCategories.join(', ')}"
                  : 'Selected menu items filter is active',
              style: const TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  bool get _isMobileGridLayout =>
      _isMobileKitchenScreen && _mobileLayoutIsGrid && !_isTabletKitchenScreen;

  EdgeInsets get _kitchenGridPadding => _isMobileGridLayout
      ? const EdgeInsets.only(top: 6, bottom: 6)
      : const EdgeInsets.all(12);

  double get _kitchenCrossAxisSpacing => _isMobileGridLayout ? 4 : 12;

  double get _kitchenMainAxisSpacing => _isMobileGridLayout ? 6 : 12;

  Widget _buildKitchenOrdersGrid() {
    if (_isMobileKitchenScreen && !_mobileLayoutIsGrid) {
      return _buildMobileOrdersListView();
    }

    final screenW = MediaQuery.sizeOf(context).width;
    final crossCols = _kitchenCrossAxisCount(screenW);
    final layoutKey = ValueKey(
      'kitchen_${_showTableAllOrders ? 'table' : 'group'}_${crossCols}_$_mobileLayoutIsGrid',
    );

    if (_showTableAllOrders) {
      final firstUnpaidIndex = _displayTableCards.indexWhere((c) => !c.isPaid);
      return MasonryGridView.count(
        key: layoutKey,
        crossAxisCount: crossCols,
        mainAxisSpacing: _kitchenMainAxisSpacing,
        crossAxisSpacing: _kitchenCrossAxisSpacing,
        padding: _kitchenGridPadding,
        itemCount: _displayTableCards.length,
        itemBuilder: (context, index) => _buildTableBatchCard(
          _displayTableCards[index],
          index + 1,
          isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
        ),
      );
    }

    final firstUnpaidIndex = _displayFilteredGroups.indexWhere(
      (g) => !g.isPaid,
    );
    return MasonryGridView.count(
      key: layoutKey,
      crossAxisCount: crossCols,
      mainAxisSpacing: _kitchenMainAxisSpacing,
      crossAxisSpacing: _kitchenCrossAxisSpacing,
      padding: _kitchenGridPadding,
      itemCount: _displayFilteredGroups.length,
      itemBuilder: (context, index) => _buildGroupCard(
        _displayFilteredGroups[index],
        index + 1,
        isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
      ),
    );
  }

  Widget _buildMobileOrdersListView() {
    if (_showTableAllOrders) {
      final firstUnpaidIndex = _displayTableCards.indexWhere((c) => !c.isPaid);
      return ListView.separated(
        key: const ValueKey('kitchen_mobile_list_table'),
        padding: const EdgeInsets.all(12),
        itemCount: _displayTableCards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildTableBatchCard(
          _displayTableCards[index],
          index + 1,
          isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
        ),
      );
    }

    final firstUnpaidIndex = _displayFilteredGroups.indexWhere(
      (g) => !g.isPaid,
    );
    return ListView.separated(
      key: const ValueKey('kitchen_mobile_list_group'),
      padding: const EdgeInsets.all(12),
      itemCount: _displayFilteredGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildGroupCard(
        _displayFilteredGroups[index],
        index + 1,
        isNext: index == firstUnpaidIndex && firstUnpaidIndex != -1,
      ),
    );
  }

  Widget _orderCardShell({
    required bool isBlinking,
    required BoxDecoration decoration,
    required Widget child,
    Duration animationDuration = const Duration(milliseconds: 400),
  }) {
    if (isBlinking) {
      return AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        decoration: decoration,
        child: child,
      );
    }
    return Container(decoration: decoration, child: child);
  }

  List<KitchenTableCard> _mergeGroupsByTable(List<TableGroup> groups) {
    final Map<String, KitchenTableCard> map = {};

    for (final group in groups) {
      if (!map.containsKey(group.docId)) {
        map[group.docId] = KitchenTableCard(
          tableName: group.tableName,
          docId: group.docId,
          isPaid: group.isPaid,
          lastTransactionId: group.lastTransactionId,
          batches: [group],
        );
      } else {
        map[group.docId]!.batches.add(group);
        if (group.isPaid) map[group.docId]!.isPaid = true;
        if (group.lastTransactionId != null &&
            group.lastTransactionId!.isNotEmpty) {
          map[group.docId]!.lastTransactionId = group.lastTransactionId;
        }
      }
    }

    for (final card in map.values) {
      card.batches.sort((a, b) => a.groupTime.compareTo(b.groupTime));
    }

    final cards = map.values.toList()
      ..sort(
        (a, b) =>
            a.batches.first.groupTime.compareTo(b.batches.first.groupTime),
      );
    return cards;
  }

  bool get _hasActiveCategoryFilter => _menuFilter.hasActiveFilter(
        showAllCategories: showAllCategories,
        selectedCategories: selectedCategories,
        selectedMenuItems: selectedMenuItems,
      );

  bool get _categoryOnlyFilterMode =>
      _useLegacyCategoryOnlyFilter ||
      (!showAllCategories &&
          selectedCategories.isNotEmpty &&
          selectedMenuItems.isEmpty);

  String _menuItemFilterKey(String category, String itemName) =>
      KitchenMenuFilter.filterKey(category, itemName);

  bool _isMenuItemIncludedInFilter(Map<String, dynamic> item) {
    return _menuFilter.matchesOrderItem(
      item: item,
      showAllCategories: showAllCategories,
      selectedCategories: selectedCategories,
      selectedMenuItems: selectedMenuItems,
      categoryOnlyMode: _categoryOnlyFilterMode,
    );
  }

  bool _hasItemSelectionForCategory(String category) {
    final prefix = '$category|';
    return selectedMenuItems.any((key) => key.startsWith(prefix));
  }

  void _selectAllMenuItemsForCategory(
    String categoryName,
    List<String> itemNames,
  ) {
    for (final itemName in itemNames) {
      selectedMenuItems.add(_menuItemFilterKey(categoryName, itemName));
    }
  }

  void _deselectAllMenuItemsForCategory(String categoryName) {
    final prefix = '$categoryName|';
    selectedMenuItems.removeWhere((key) => key.startsWith(prefix));
  }

  bool? _categoryCheckboxValue(String categoryName, List<String> itemNames) {
    if (!selectedCategories.contains(categoryName)) return false;
    if (itemNames.isEmpty) return true;

    var selectedCount = 0;
    for (final itemName in itemNames) {
      if (selectedMenuItems.contains(_menuItemFilterKey(categoryName, itemName))) {
        selectedCount++;
      }
    }
    if (selectedCount == 0) return false;
    if (selectedCount == itemNames.length) return true;
    return null;
  }

  void _showCategoryFilterDialog(BuildContext context) async {
    final cache = Get.find<MenuCacheService>();
    await cache.loadFromCacheOnly();
    _menuFilter.invalidate();
    if (!mounted) return;

    final categoryNames = cache.getCategoryNamesSorted();
    final menuItemsByCategory = cache.getItemsByCategoryMap();

    if (_useLegacyCategoryOnlyFilter) {
      for (final categoryName in selectedCategories) {
        _selectAllMenuItemsForCategory(
          categoryName,
          menuItemsByCategory[categoryName] ?? const [],
        );
      }
      _useLegacyCategoryOnlyFilter = false;
      unawaited(
        KitchenSettings.saveCategoryFilter(
          showAll: showAllCategories,
          categories: selectedCategories,
          menuItems: selectedMenuItems,
        ),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        if (categoryNames.isEmpty) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Filter by Category",
              style: TextStyle(
                fontFamily: fontMulishSemiBold,
                fontSize: 18,
              ),
            ),
            content: const Text(
              'No menu categories in cache. Pull to refresh on the Dashboard to load the menu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Close"),
              ),
            ],
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyFilterChanges() {
              setDialogState(() {});
              _applyCategoryFilterChanges();
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Filter by Category",
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  fontSize: 18,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        showAllCategories = value ?? true;
                        if (showAllCategories) {
                          selectedCategories.clear();
                          selectedMenuItems.clear();
                          _useLegacyCategoryOnlyFilter = false;
                        }
                        applyFilterChanges();
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: categoryNames.length,
                        itemBuilder: (context, index) {
                          final categoryName = categoryNames[index];
                          final itemNames =
                              menuItemsByCategory[categoryName] ??
                              const <String>[];
                          final categoryValue = _categoryCheckboxValue(
                            categoryName,
                            itemNames,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CheckboxListTile(
                                title: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontFamily: fontMulishSemiBold,
                                    fontSize: 14,
                                  ),
                                ),
                                value: categoryValue,
                                tristate: true,
                                activeColor: Colors.green,
                                enabled: !showAllCategories,
                                onChanged: showAllCategories
                                    ? null
                                    : (bool? value) {
                                        if (value == true || value == null) {
                                          selectedCategories.add(categoryName);
                                          _selectAllMenuItemsForCategory(
                                            categoryName,
                                            itemNames,
                                          );
                                        } else {
                                          selectedCategories.remove(
                                            categoryName,
                                          );
                                          _deselectAllMenuItemsForCategory(
                                            categoryName,
                                          );
                                        }
                                        applyFilterChanges();
                                      },
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                              if (!showAllCategories &&
                                  selectedCategories.contains(categoryName))
                                ...itemNames.map((itemName) {
                                  final itemKey = _menuItemFilterKey(
                                    categoryName,
                                    itemName,
                                  );
                                  final itemSelected = selectedMenuItems
                                      .contains(itemKey);

                                  return Padding(
                                    padding: const EdgeInsets.only(left: 28),
                                    child: CheckboxListTile(
                                      title: Text(
                                        itemName,
                                        style: const TextStyle(
                                          fontFamily: fontMulishRegular,
                                          fontSize: 13,
                                        ),
                                      ),
                                      value: itemSelected,
                                      activeColor: Colors.green,
                                      onChanged: (bool? value) {
                                        if (value == true) {
                                          selectedMenuItems.add(itemKey);
                                          selectedCategories.add(categoryName);
                                        } else {
                                          selectedMenuItems.remove(itemKey);
                                          if (!_hasItemSelectionForCategory(
                                            categoryName,
                                          )) {
                                            selectedCategories.remove(
                                              categoryName,
                                            );
                                          }
                                        }
                                        applyFilterChanges();
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  );
                                }),
                              if (index < categoryNames.length - 1)
                                const Divider(height: 1),
                            ],
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
                    showAllCategories = true;
                    selectedCategories.clear();
                    selectedMenuItems.clear();
                    _useLegacyCategoryOnlyFilter = false;
                    applyFilterChanges();
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    "Done",
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

  void _applyCategoryFilterChanges() {
    _useLegacyCategoryOnlyFilter = false;
    setState(_rebuildDisplayFromCache);
    unawaited(
      KitchenSettings.saveCategoryFilter(
        showAll: showAllCategories,
        categories: selectedCategories,
        menuItems: selectedMenuItems,
      ),
    );
  }

  // Filter groups by selected categories
  List<TableGroup> _filterByCategories(List<TableGroup> groups) {
    if (!_hasActiveCategoryFilter) {
      return groups;
    }

    return groups
        .map((group) {
          if (group.isZomato) {
            if (ZomatoOrderUtils.isCompletedStatus(group.zomatoStatus)) {
              return null;
            }
            return group;
          }
          // Filter items in this group by selected categories
          final filteredItems = group.items
              .asMap()
              .entries
              .where((entry) {
                final item = TableItemServed.asItemMap(entry.value);
                if (item == null) return false;
                return _isMenuItemIncludedInFilter(item);
              })
              .map((entry) {
                final item = TableItemServed.asItemMap(entry.value)!;
                final copy = Map<String, dynamic>.from(item);
                copy['__itemIndex'] = entry.key;
                return copy;
              })
              .toList();

          // If no items match, return null (will be filtered out)
          if (filteredItems.isEmpty) return null;

          // Return new group with filtered items
          return TableGroup(
            group.tableName,
            filteredItems,
            group.groupTime,
            key: group.key,
            docId: group.docId,
            isPaid: group.isPaid,
            groupIndex: group.groupIndex,
            lastTransactionId: group.lastTransactionId,
            source: group.source,
            screenshotUrl: group.screenshotUrl,
            zomatoStatus: group.zomatoStatus,
          );
        })
        .whereType<TableGroup>()
        .toList(); // Remove nulls
  }

  // Check if the group contains items from selected categories
  bool _shouldPlaySoundForGroup(TableGroup group) {
    if (!_hasActiveCategoryFilter) {
      return true;
    }

    // Check if any item in the group matches selected categories
    for (var item in group.items) {
      final itemMap = TableItemServed.asItemMap(item);
      if (itemMap == null) continue;
      if (_isMenuItemIncludedInFilter(itemMap)) {
        return true;
      }
    }

    return false;
  }

  bool get _isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isTabletKitchenScreen =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  bool get _isMobileKitchenScreen =>
      _isNativeMobile || MediaQuery.sizeOf(context).width < 600;

  int _kitchenCrossAxisCount(double screenW) {
    if (_isMobileKitchenScreen) {
      if (!_mobileLayoutIsGrid) return 1;
      if (_isTabletKitchenScreen) {
        return _responsiveKitchenColumns(screenW);
      }
      return 2;
    }
    return _responsiveKitchenColumns(screenW);
  }

  int _responsiveKitchenColumns(double screenW) {
    if (screenW > 1200) return 5;
    if (screenW > 900) return 4;
    if (screenW > 600) return 3;
    return 2;
  }

  void _setMobileLayoutIsGrid(bool isGrid) {
    if (_mobileLayoutIsGrid == isGrid) return;
    setState(() => _mobileLayoutIsGrid = isGrid);
    KitchenSettings.setMobileOrdersGridLayout(isGrid);
  }

  Widget _buildMobileLayoutToggle() {
    const navy = Color(0xFF1A3A5C);
    const orange = Color(0xFFf57c35);

    Widget option({
      required IconData icon,
      required String tooltip,
      required bool selected,
      required bool isGrid,
    }) {
      return IconButton(
        icon: Icon(icon, size: 22),
        tooltip: tooltip,
        color: selected ? orange : navy.withValues(alpha: 0.55),
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? orange.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        onPressed: () => _setMobileLayoutIsGrid(isGrid),
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: navy.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            icon: Icons.view_list_rounded,
            tooltip: 'List view',
            selected: !_mobileLayoutIsGrid,
            isGrid: false,
          ),
          option(
            icon: Icons.grid_view_rounded,
            tooltip: _isTabletKitchenScreen
                ? 'Grid view (responsive columns)'
                : 'Grid view (2 columns)',
            selected: _mobileLayoutIsGrid,
            isGrid: true,
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenOrderTabs() {
    const navy = Color(0xFF1A3A5C);
    const orange = Color(0xFFf57c35);

    Widget tabButton(String label, int index) {
      final selected = _kitchenOrderTabIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => _onKitchenOrderTabChanged(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? orange : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: selected ? fontMulishBold : fontMulishSemiBold,
                fontSize: 14,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: navy,
      child: Row(
        children: [tabButton('All Orders', 0), tabButton('Served Orders', 1)],
      ),
    );
  }

  Widget _buildOrderTypeFilter() {
    const navy = Color(0xFF1A3A5C);

    Widget radioTile(String label, int value) {
      final selected = _orderTypeFilterIndex == value;
      return Expanded(
        child: InkWell(
          onTap: () => _onOrderTypeFilterChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<int>(
                  value: value,
                  groupValue: _orderTypeFilterIndex,
                  activeColor: const Color(0xFFf57c35),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: _onOrderTypeFilterChanged,
                ),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: selected
                          ? fontMulishBold
                          : fontMulishSemiBold,
                      fontSize: 13,
                      color: navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            radioTile('All', 0),
            radioTile('Table', 1),
            radioTile('TakeAway', 2),
            radioTile('Zomato', 3),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kitchen",
          style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 16),
        ),
        bottom: _showServeOrderScreen
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _buildKitchenOrderTabs(),
              )
            : null,
        actions: [
          if (_isMobileKitchenScreen) _buildMobileLayoutToggle(),
          // Filter button with badge showing count
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
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
                      color: Colors.red,
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
      body: !_kitchenStreamReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildOrderTypeFilter(),
                Expanded(
                  child:
                      (_showTableAllOrders
                          ? _displayTableCards.isEmpty
                          : _displayFilteredGroups.isEmpty)
                      ? _buildKitchenEmptyState()
                      : _buildKitchenOrdersGrid(),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupCard(
    TableGroup group,
    int queueNumber, {
    bool isNext = false,
  }) {
    final time = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
    final isBlinking = blinkingGroupKey == group.key.hashCode;
    final isDelayed = _isOrderDelayed(time);
    final isDelayedBlinking = _isDelayedGroupBlinking(group);

    if (group.tableName.contains("Take Away") && isDelayed && group.isPaid) {
      deleteTable(group.docId);
    }

    return KeyedSubtree(
      key: ValueKey(group.key),
      child: ListenableBuilder(
        listenable: _minuteTick,
        builder: (context, _) {
          final tickTime = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
          final tickIsDelayed = _isOrderDelayed(tickTime);
          return _orderCardShell(
            isBlinking: isBlinking,
            animationDuration: const Duration(milliseconds: 800),
            decoration: _orderCardDecoration(
              isBlinking,
              tickIsDelayed,
              isNext,
              compact: _isMobileGridLayout,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderHeader(
                  group.tableName,
                  group.isPaid,
                  queueNumber,
                  isZomato: group.isZomato,
                  isNext: isNext,
                  onPaidHeaderTap: group.isZomato
                      ? () => _markTableServed(group.tableName, group.docId)
                      : null,
                  compact: _isMobileGridLayout,
                ),
                _buildTimeBar(
                  tickTime,
                  tickIsDelayed,
                  compact: _isMobileGridLayout,
                ),
                if (group.isZomato &&
                    (group.screenshotUrl?.isNotEmpty ?? false))
                  ZomatoOrderCardBody(
                    docId: group.docId,
                    screenshotUrl: group.screenshotUrl!,
                    status: group.zomatoStatus ?? 'Pending',
                    compact: _isMobileGridLayout,
                  )
                else
                  Padding(
                    padding: EdgeInsets.all(_isMobileGridLayout ? 6 : 12),
                    child: ListenableBuilder(
                      listenable: _itemSelection.listenableFor(group.docId),
                      builder: (context, _) {
                        final selectionMode = _itemSelection.isSelectionModeFor(
                          group.docId,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...group.items.asMap().entries.map(
                              (entry) => _buildItemRow(
                                entry.value,
                                docId: group.docId,
                                groupIndex: group.groupIndex,
                                itemIndexInGroup:
                                    (entry.value['__itemIndex'] as int?) ??
                                    entry.key,
                                selectionMode: selectionMode,
                                isDelayed: tickIsDelayed,
                                isDelayedBlinking: isDelayedBlinking,
                              ),
                            ),
                            TableItemSelectionActionBar(
                              docId: group.docId,
                              controller: _itemSelection,
                              showDeleteButton:
                                  Get.find<RestaurantSession>()
                                      .profile
                                      .value
                                      ?.isAdmin ??
                                  false,
                              action:
                                  _showServeOrderScreen &&
                                      _kitchenOrderTabIndex == 1
                                  ? TableItemSelectionAction.markPending
                                  : TableItemSelectionAction.serve,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableBatchCard(
    KitchenTableCard tableCard,
    int queueNumber, {
    bool isNext = false,
  }) {
    final isZomato =
        tableCard.batches.any((batch) => batch.isZomato) ||
        ZomatoOrderUtils.isZomatoOrderName(tableCard.tableName);
    final zomatoGroup = isZomato
        ? tableCard.batches.firstWhere(
            (batch) => batch.isZomato,
            orElse: () => tableCard.batches.first,
          )
        : null;
    final isBlinking = tableCard.batches.any(
      (g) => blinkingGroupKey == g.key.hashCode,
    );

    for (final batch in tableCard.batches) {
      final time = DateTime.fromMillisecondsSinceEpoch(batch.groupTime);
      final isDelayed = _isOrderDelayed(time);
      if (tableCard.tableName.contains("Take Away") &&
          isDelayed &&
          tableCard.isPaid) {
        deleteTable(tableCard.docId);
        break;
      }
    }

    return KeyedSubtree(
      key: ValueKey(tableCard.docId),
      child: ListenableBuilder(
        listenable: _minuteTick,
        builder: (context, _) {
          final tickIsDelayed = tableCard.batches.any((batch) {
            final batchTime = DateTime.fromMillisecondsSinceEpoch(
              batch.groupTime,
            );
            return _isOrderDelayed(batchTime);
          });
          return _orderCardShell(
            isBlinking: isBlinking,
            decoration: _orderCardDecoration(
              isBlinking,
              tickIsDelayed,
              isNext,
              compact: _isMobileGridLayout,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderHeader(
                  tableCard.tableName,
                  tableCard.isPaid,
                  queueNumber,
                  isZomato: isZomato,
                  isNext: isNext,
                  onPaidHeaderTap: isZomato
                      ? () => _markTableServed(
                            tableCard.tableName,
                            tableCard.docId,
                          )
                      : null,
                  compact: _isMobileGridLayout,
                ),
                if (isZomato &&
                    zomatoGroup != null &&
                    (zomatoGroup.screenshotUrl?.isNotEmpty ?? false)) ...[
                  _buildTimeBar(
                    DateTime.fromMillisecondsSinceEpoch(zomatoGroup.groupTime),
                    _isOrderDelayed(
                      DateTime.fromMillisecondsSinceEpoch(
                        zomatoGroup.groupTime,
                      ),
                    ),
                    compact: _isMobileGridLayout,
                  ),
                  ZomatoOrderCardBody(
                    docId: tableCard.docId,
                    screenshotUrl: zomatoGroup.screenshotUrl!,
                    status: zomatoGroup.zomatoStatus ?? 'Pending',
                    compact: _isMobileGridLayout,
                  ),
                ] else
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _isMobileGridLayout ? 6 : 12,
                      8,
                      _isMobileGridLayout ? 4 : 6,
                      _isMobileGridLayout ? 6 : 12,
                    ),
                    child: ListenableBuilder(
                      listenable: _itemSelection.listenableFor(tableCard.docId),
                      builder: (context, _) {
                        final selectionMode = _itemSelection.isSelectionModeFor(
                          tableCard.docId,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var i = 0;
                              i < tableCard.batches.length;
                              i++
                            ) ...[
                              if (i > 0) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: DottedLine(
                                    dashColor: Colors.grey.shade300,
                                    lineThickness: 1,
                                    dashLength: 4,
                                    dashGapLength: 4,
                                  ),
                                ),
                              ],
                              Builder(
                                builder: (context) {
                                  final batch = tableCard.batches[i];
                                  final batchTime =
                                      DateTime.fromMillisecondsSinceEpoch(
                                        batch.groupTime,
                                      );
                                  final batchDelayed = _isOrderDelayed(
                                    batchTime,
                                  );
                                  final batchDelayedBlinking =
                                      _isDelayedGroupBlinking(batch);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _KitchenRelativeTime(
                                          time: batchTime,
                                          tick: _minuteTick,
                                          formatter: formatRelativeTime,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: fontMulishRegular,
                                            color: batchDelayed
                                                ? Colors.red.shade700
                                                : Colors.grey.shade500,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...batch.items.asMap().entries.map(
                                        (entry) => _buildItemRow(
                                          entry.value,
                                          docId: tableCard.docId,
                                          groupIndex: batch.groupIndex,
                                          itemIndexInGroup:
                                              (entry.value['__itemIndex']
                                                  as int?) ??
                                              entry.key,
                                          selectionMode: selectionMode,
                                          isDelayed: batchDelayed,
                                          isDelayedBlinking:
                                              batchDelayedBlinking,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                            TableItemSelectionActionBar(
                              docId: tableCard.docId,
                              controller: _itemSelection,
                              showDeleteButton:
                                  Get.find<RestaurantSession>()
                                      .profile
                                      .value
                                      ?.isAdmin ??
                                  false,
                              action:
                                  _showServeOrderScreen &&
                                      _kitchenOrderTabIndex == 1
                                  ? TableItemSelectionAction.markPending
                                  : TableItemSelectionAction.serve,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _markTableServed(String tableName, String docId) {
    if (selectedCategories.isNotEmpty && !showAllCategories) return;
    showServedDialog(context, tableName, () async {
      _playDeleteSound();
      if (ZomatoOrderUtils.isZomatoOrderName(tableName)) {
        await ZomatoOrderProgressDialog.run(
          context,
          action: () =>
              Get.find<ZomatoOrdersRepository>().removeOrder(docId: docId),
        );
      } else if (isDiningTableName(tableName)) {
        await _updateTableItemsInFirestore(tableName, [], false);
      } else {
        await FirestorePaths.scoped('tables').doc(docId).delete();
      }
    });
  }

  BoxDecoration _orderCardDecoration(
    bool isBlinking,
    bool isDelayed,
    bool isNext, {
    bool compact = false,
  }) {
    final radius = compact ? 8.0 : 12.0;
    final borderWidth = compact
        ? (isNext ? 2.0 : 1.5)
        : (isNext ? 2.5 : (isDelayed ? 2.0 : 1.0));
    return BoxDecoration(
      color: isBlinking ? _blinkColor : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: compact
          ? []
          : [
              BoxShadow(
                color: isNext
                    ? Colors.green.withValues(alpha: 0.35)
                    : isDelayed
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isNext ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
      border: isNext
          ? Border.all(color: Colors.green, width: borderWidth)
          : isDelayed
          ? Border.all(color: Colors.red, width: borderWidth)
          : Border.all(color: Colors.grey.shade200, width: borderWidth),
    );
  }

  Widget _buildOrderHeader(
    String tableName,
    bool isPaid,
    int queueNumber, {
    bool isZomato = false,
    bool isNext = false,
    VoidCallback? onPaidHeaderTap,
    VoidCallback? onPaidDoubleTap,
    bool compact = false,
  }) {
    final paid = isPaid == true;
    final zomato = isZomato || ZomatoOrderUtils.isZomatoOrderName(tableName);
    final header = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: zomato ? const Color(0xFFE53935) : const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(compact ? 7 : 10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (zomato)
                  SizedBox()
                else
                  SvgPicture.asset(
                    tableName.contains("Take Away") ? icon_packing : icon_table,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    width: tableName.contains("Take Away")
                        ? (compact ? 15 : 18)
                        : (compact ? 18 : 22),
                  ),
                SizedBox(width: compact ? 6 : 8),
                Flexible(
                  child: Text(
                    tableName,
                    style: TextStyle(
                      fontFamily: zomato || tableName.contains("Take Away")
                          ? fontMulishBold
                          : fontMulishSemiBold,
                      fontSize: compact ? 13 : 16,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // if (zomato) ...[
                //   const SizedBox(width: 6),
                //   Container(
                //     padding: const EdgeInsets.symmetric(
                //       horizontal: 6,
                //       vertical: 2,
                //     ),
                //     decoration: BoxDecoration(
                //       color: Colors.white.withValues(alpha: 0.18),
                //       borderRadius: BorderRadius.circular(10),
                //     ),
                //     child: const Text(
                //       'ZOMATO',
                //       style: TextStyle(
                //         color: Colors.white,
                //         fontSize: 9,
                //         fontFamily: fontMulishBold,
                //       ),
                //     ),
                //   ),
                // ],
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 0),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNext ? Colors.green : const Color(0xFFf57c35),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Text(
              '$queueNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: fontMulishBold,
              ),
            ),
          ),

          if (isNext)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "NEXT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: fontMulishBold,
                ),
              ),
            ),
          if (paid)
            GestureDetector(
              onDoubleTap: onPaidDoubleTap,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "PAID",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: fontMulishBold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (paid && onPaidHeaderTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPaidHeaderTap,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(compact ? 7 : 10),
          ),
          child: header,
        ),
      );
    }

    return header;
  }

  Widget _buildTimeBar(DateTime time, bool isDelayed, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      color: isDelayed ? _delayedItemBackground : const Color(0xFFF5F6FA),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: isDelayed ? Colors.red : Colors.grey.shade700,
          ),
          const SizedBox(width: 6),
          _KitchenRelativeTime(
            time: time,
            tick: _minuteTick,
            formatter: formatRelativeTime,
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
              color: isDelayed ? Colors.red : Colors.grey.shade800,
            ),
          ),
          if (isDelayed) ...[
            const Spacer(),
            const Text(
              "DELAYED",
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontFamily: fontMulishBold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(
    Map<String, dynamic> item, {
    required String docId,
    required int groupIndex,
    required int itemIndexInGroup,
    required bool selectionMode,
    bool isDelayed = false,
    bool isDelayedBlinking = false,
  }) {
    final key = TableItemKey(
      docId: docId,
      groupIndex: groupIndex,
      itemIndexInGroup: itemIndexInGroup,
    );
    final served = TableItemServed.isServed(item);
    final showDelayedBackground = isDelayed && !served;

    final row = OrderItemRow(
      item: item,
      docId: docId,
      groupIndex: groupIndex,
      itemIndexInGroup: itemIndexInGroup,
      selectionController: _itemSelection,
      selectionMode: selectionMode,
      isSelected: _itemSelection.isSelected(key),
      style: OrderItemRowStyle.kitchen,
      selectionForServedItems:
          _showServeOrderScreen && _kitchenOrderTabIndex == 1,
    );

    if (!showDelayedBackground) return row;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDelayedBlinking
            ? _delayedItemBlinkBackground
            : _delayedItemBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: row,
    );
  }

  String formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min${difference.inMinutes > 1 ? "s" : ""} ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hr${difference.inHours > 1 ? "s" : ""} ago";
    } else if (difference.inDays == 1) {
      return "yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago";
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(time);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KitchenSettings.showTableAllOrders.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.showServeOrderScreen.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.mobileOrdersGridLayout.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.backgroundOrderRingtoneEnabled.removeListener(
      _onBackgroundRingtoneSettingChanged,
    );
    _tablesSub?.cancel();
    _timer?.cancel();
    _delayedBlinkTimer?.cancel();
    _minuteTick.dispose();
    audioPlayer.dispose();
    updateAudioPlayer.dispose();
    deleteAudioPlayer.dispose();
    super.dispose();
  }

  void deleteTable(String docId) async {
    await FirestorePaths.scoped('tables').doc(docId).delete();
  }

  void showServedDialog(
    BuildContext context,
    String tableName,
    VoidCallback onServed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isTakeAwayOrderName(tableName)
                ? "Mark as Delivered?"
                : "Mark as Served?",
            style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
          ),
          content: Text(
            isTakeAwayOrderName(tableName)
                ? "Are you sure you want to mark '$tableName' as delivered?"
                : "Are you sure you want to mark '$tableName' as served?",
            style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
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
                Navigator.pop(context);
                onServed();
              },
              child: Text(
                isTakeAwayOrderName(tableName) ? "Delivered" : "Served",
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
  }

  Future<void> _updateTableItemsInFirestore(
    String tableName,
    List<List<Map<String, dynamic>>> groups,
    bool isBillPaid,
  ) async {
    try {
      await Get.find<TablesRepository>().updateTableItems(
        tableName: tableName,
        groups: groups,
        isBillPaid: isBillPaid,
      );
    } catch (e) {
      print("ERROR: Failed to update Firestore: $e");
      if (e is FirebaseException) {
        print("Firebase error code: ${e.code}");
        print("Firebase error message: ${e.message}");
      }
    }
  }
}

class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;
  final String key;
  final String docId;
  final bool isPaid;
  final int groupIndex;
  final String? lastTransactionId;
  final String? source;
  final String? screenshotUrl;
  final String? zomatoStatus;

  bool get isZomato =>
      ZomatoOrderUtils.isZomatoSource(source) ||
      ZomatoOrderUtils.isZomatoOrderName(tableName);

  TableGroup(
    this.tableName,
    this.items,
    this.groupTime, {
    required this.key,
    required this.docId,
    required this.isPaid,
    required this.groupIndex,
    this.lastTransactionId,
    this.source,
    this.screenshotUrl,
    this.zomatoStatus,
  });
}

class KitchenTableCard {
  final String tableName;
  final String docId;
  bool isPaid;
  String? lastTransactionId;
  final List<TableGroup> batches;

  KitchenTableCard({
    required this.tableName,
    required this.docId,
    required this.isPaid,
    this.lastTransactionId,
    required this.batches,
  });
}

/// Rebuilds only this label on the minute tick — avoids refreshing the whole grid.
class _KitchenRelativeTime extends StatelessWidget {
  final DateTime time;
  final ValueListenable<int> tick;
  final String Function(DateTime) formatter;
  final TextStyle style;

  const _KitchenRelativeTime({
    required this.time,
    required this.tick,
    required this.formatter,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, __) => Text(formatter(time), style: style),
    );
  }
}
