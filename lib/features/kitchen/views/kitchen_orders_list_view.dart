import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_sync_channel.dart';
import 'package:demo/core/widgets/firestore_sync_status_chip.dart';
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
import 'package:demo/features/kitchen/services/kitchen_cross_table_pending_index.dart';
import 'package:demo/features/kitchen/services/kitchen_menu_filter.dart';
import 'package:demo/features/kitchen/services/kitchen_preparation_view_index.dart';
import 'package:demo/features/kitchen/widgets/kitchen_cross_table_pending_sheet.dart';
import 'package:demo/features/kitchen/widgets/kitchen_new_order_dialog.dart';
import 'package:demo/features/kitchen/widgets/kitchen_preparation_orders_list.dart';
import 'package:demo/features/kitchen/widgets/kitchen_theme.dart';
import 'package:demo/features/kitchen/services/kitchen_web_bell_service.dart';
import 'package:demo/features/kitchen/services/kitchen_bell_sound.dart';
import 'package:demo/features/kitchen/services/kitchen_background_alert_service.dart';
import 'package:demo/features/transactions/services/reverse_billing_service.dart';
import 'package:demo/features/transactions/repositories/transactions_repository.dart';
import 'package:demo/features/settings/utils/mark_as_delivered_permission.dart';
import 'package:demo/features/tables/repositories/table_item_served.dart';
import 'package:demo/features/tables/services/serve_notification_service.dart';
import 'package:demo/features/tables/utils/table_serve_change_utils.dart';
import 'package:demo/features/tables/repositories/tables_repository.dart';
import 'package:demo/features/tables/services/shared_tables_snapshot_service.dart';
import 'package:demo/features/tables/widgets/order_item_row.dart';
import 'package:demo/features/zomato/widgets/zomato_order_card_body.dart';
import 'package:demo/features/zomato/services/zomato_order_serve_service.dart';
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
  final ScrollController _gridScrollController = ScrollController();
  final ValueNotifier<int> _minuteTick = ValueNotifier(0);
  bool _kitchenStreamReady = false;
  bool _isRefreshingKitchen = false;

  /// True when the kitchen list was last shown empty (no orders to display).
  bool _wasKitchenEmpty = false;
  List<TableGroup> _lastUpdatedGroups = [];
  List<TableGroup> _displayFilteredGroups = [];
  List<KitchenTableCard> _displayTableCards = [];
  KitchenCrossTablePendingIndex _crossTablePendingIndex =
      KitchenCrossTablePendingIndex.empty();
  List<KitchenPreparationItemGroup> _preparationItemGroups = [];
  Map<String, Set<String>> _previousPrepItemLineTokens = {};
  Set<String> _blinkingPrepItemKeys = {};
  Color _prepBlinkColor = Colors.lightGreenAccent.shade100;
  Timer? _prepBlinkTimer;
  VoidCallback? _menuCacheListener;
  int? blinkingGroupKey;
  // Per-line highlights when items are added or edited on an existing table.
  Map<String, _KitchenItemHighlightKind> _highlightedItemKinds = {};
  Timer? _itemHighlightTimer;
  // Color used for the currently blinking card: green for a new order,
  // yellow for an update (quantity changed / item added on existing table).
  Color _blinkColor = Colors.lightGreenAccent.shade100;
  Timer? _timer;
  final TableItemSelectionController _itemSelection =
      TableItemSelectionController();

  static final Color _newOrderBlinkColor = Colors.lightGreenAccent.shade100;
  static final Color _updateBlinkColor = Colors.yellow.shade300;
  static final Color _newItemHighlightColor = Colors.brown.shade100;
  static final Color _serveBlinkColor = const Color(
    TableServeChangeUtils.serveBlinkColor,
  );
  static final Color _delayedItemBackground = KitchenTheme.delayedBarBg;
  static final Color _delayedItemBlinkBackground = KitchenTheme.delayedBarBlink;
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

  void _restoreGridScroll(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridScrollController.hasClients) return;
      final maxExtent = _gridScrollController.position.maxScrollExtent;
      final target = offset.clamp(0.0, maxExtent);
      if ((_gridScrollController.offset - target).abs() > 0.5) {
        _gridScrollController.jumpTo(target);
      }
    });
  }

  void _setStatePreservingScroll(VoidCallback fn) {
    final scrollOffset = _gridScrollController.hasClients
        ? _gridScrollController.offset
        : null;
    setState(fn);
    if (scrollOffset != null) {
      _restoreGridScroll(scrollOffset);
    }
  }

  void _startDelayedBlinkAnimation(Set<int> groupKeyHashes) {
    _delayedBlinkTimer?.cancel();
    if (groupKeyHashes.isEmpty || !mounted) return;

    _setStatePreservingScroll(() {
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
        _setStatePreservingScroll(() {
          _delayedBlinkGroupKeys.clear();
          _delayedBlinkHighlight = false;
        });
        return;
      }

      _setStatePreservingScroll(
        () => _delayedBlinkHighlight = !_delayedBlinkHighlight,
      );
    });
  }

  bool get _canRingBell {
    if (KitchenSettings.backgroundOrderRingtoneEnabled.value) {
      return _appLifecycleState != AppLifecycleState.detached;
    }
    return _appLifecycleState == AppLifecycleState.resumed &&
        widget.isTabActive;
  }

  bool get _isAppInBackground =>
      _appLifecycleState == AppLifecycleState.paused ||
      _appLifecycleState == AppLifecycleState.inactive ||
      _appLifecycleState == AppLifecycleState.hidden;

  Future<void> _preparePlayersForRing() async {
    if (KitchenSettings.backgroundOrderRingtoneEnabled.value &&
        _isAppInBackground) {
      await _configureAudioPlayers();
    }
  }

  Future<void> _initAudioPlayers() async {
    for (final player in [audioPlayer, updateAudioPlayer, deleteAudioPlayer]) {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
    }
    await _configureAudioPlayers();
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

  String _itemContentSignature(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final qty = item['qty']?.toString() ?? '1';
    final remarks = item['remarks']?.toString() ?? '';
    final price = item['price']?.toString() ?? '';
    return '$name~$qty~$remarks~$price';
  }

  Map<String, String> _itemSignatureMapForGroup(TableGroup group) {
    final signatures = <String, String>{};
    for (var i = 0; i < group.items.length; i++) {
      final item = TableItemServed.asItemMap(group.items[i]);
      if (item == null) continue;
      final key = TableItemServed.keyForItem(
        docId: group.docId,
        item: item,
        groupIndexFallback: group.groupIndex,
        itemIndexFallback: i,
      );
      signatures[key.id] = _itemContentSignature(item);
    }
    return signatures;
  }

  void _collectNewItemHighlights(
    TableGroup group,
    Map<String, _KitchenItemHighlightKind> highlights,
  ) {
    for (var i = 0; i < group.items.length; i++) {
      final item = TableItemServed.asItemMap(group.items[i]);
      if (item == null) continue;
      final key = TableItemServed.keyForItem(
        docId: group.docId,
        item: item,
        groupIndexFallback: group.groupIndex,
        itemIndexFallback: i,
      );
      highlights[key.id] = _KitchenItemHighlightKind.newItem;
    }
  }

  void _collectChangedItemHighlights({
    required TableGroup previous,
    required TableGroup current,
    required Map<String, _KitchenItemHighlightKind> highlights,
  }) {
    final previousSignatures = _itemSignatureMapForGroup(previous);

    for (var i = 0; i < current.items.length; i++) {
      final item = TableItemServed.asItemMap(current.items[i]);
      if (item == null) continue;
      final key = TableItemServed.keyForItem(
        docId: current.docId,
        item: item,
        groupIndexFallback: current.groupIndex,
        itemIndexFallback: i,
      );
      final previousSignature = previousSignatures[key.id];
      final currentSignature = _itemContentSignature(item);

      if (previousSignature == null) {
        highlights[key.id] = _KitchenItemHighlightKind.newItem;
      } else if (previousSignature != currentSignature) {
        highlights[key.id] = _KitchenItemHighlightKind.edited;
      }
    }
  }

  void _scheduleItemHighlightsForUpdates({
    required Iterable<String> groupKeys,
    required Map<String, TableGroup> keyToGroup,
  }) {
    if (_showPreparationView && _orderTypeFilterIndex != 3) return;

    final highlights = <String, _KitchenItemHighlightKind>{};
    for (final groupKey in groupKeys) {
      final current = keyToGroup[groupKey];
      if (current == null) continue;

      final previous = _previousKeyToGroup[groupKey];
      if (previous == null) {
        _collectNewItemHighlights(current, highlights);
      } else {
        _collectChangedItemHighlights(
          previous: previous,
          current: current,
          highlights: highlights,
        );
      }
    }

    if (highlights.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _itemHighlightTimer?.cancel();
      _setStatePreservingScroll(() {
        _highlightedItemKinds = highlights;
      });
      _itemHighlightTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _setStatePreservingScroll(() => _highlightedItemKinds = {});
      });
    });
  }

  void _scheduleServeBlink({
    required String key,
    required Map<String, TableGroup> keyToGroup,
    required Set<String> currentKeys,
    required Map<String, String> currentSignatures,
    required Set<String> currentDocIds,
    required String serveEventKey,
  }) {
    final previousGroup = _previousKeyToGroup[key];
    final currentGroup = keyToGroup[key];

    previousKeys = currentKeys;
    _previousSignatures = currentSignatures;
    _previousDocIds = currentDocIds;
    _previousKeyToGroup = keyToGroup;

    if (_showPreparationView && _orderTypeFilterIndex != 3) {
      return;
    }

    final group = currentGroup;
    final shouldPlaySound = group != null
        ? _shouldPlaySoundForGroup(group)
        : true;

    if (shouldPlaySound && _canRingBell) {
      if (kIsWeb) {
        unawaited(_playWebKitchenBell(KitchenBellSound.serve));
      } else {
        final servedItemKeyIds =
            TableServeChangeUtils.newlyServedTableItemKeyIds(
              currentGroup?.docId ?? '',
              previousGroup?.items ?? const [],
              currentGroup?.items ?? const [],
            );
        unawaited(
          Get.find<ServeNotificationService>().tryPlayServeAlert(
            eventKey: serveEventKey,
            kitchenEligible: true,
            dashboardEligible: false,
            servedItemKeyIds: servedItemKeyIds,
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _setStatePreservingScroll(() {
        blinkingGroupKey = key.hashCode;
        _blinkColor = _serveBlinkColor;
      });

      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (blinkingGroupKey == key.hashCode) {
          _setStatePreservingScroll(() => blinkingGroupKey = null);
        }
      });
    });
  }

  void _showNewOrderDialog(TableGroup group) {
    if (!mounted) return;
    if (_appLifecycleState != AppLifecycleState.resumed ||
        !widget.isTabActive) {
      return;
    }

    unawaited(
      KitchenNewOrderDialog.show(
        context,
        tableName: group.tableName,
        items: group.items,
        isZomato: group.isZomato,
        orderTime: DateTime.fromMillisecondsSinceEpoch(group.groupTime),
        screenshotUrl: group.screenshotUrl,
      ),
    );
  }

  void _scheduleBlink({
    required String key,
    required Map<String, TableGroup> keyToGroup,
    required Set<String> currentKeys,
    required Map<String, String> currentSignatures,
    required Set<String> currentDocIds,
    required bool isUpdate,
  }) {
    previousKeys = currentKeys;
    _previousSignatures = currentSignatures;
    _previousDocIds = currentDocIds;
    _previousKeyToGroup = keyToGroup;

    if (_showPreparationView && _orderTypeFilterIndex != 3) {
      return;
    }

    final group = keyToGroup[key];
    final shouldPlaySound = group != null
        ? _shouldPlaySoundForGroup(group)
        : true;

    // Play immediately. Post-frame callbacks are not scheduled when the screen
    // is locked or the app is in the background.
    if (shouldPlaySound && _canRingBell) {
      if (isUpdate) {
        _playUpdateSound();
      } else {
        _playNotificationSound();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _setStatePreservingScroll(() {
        blinkingGroupKey = key.hashCode;
        _blinkColor = isUpdate ? _updateBlinkColor : _newOrderBlinkColor;
      });

      if (!isUpdate) {
        final group = keyToGroup[key];
        if (group != null) {
          _showNewOrderDialog(group);
        }
      }

      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (blinkingGroupKey == key.hashCode) {
          _setStatePreservingScroll(() => blinkingGroupKey = null);
        }
      });
    });
  }

  // Multiple category selection
  Set<String> selectedCategories = {};
  Set<String> selectedMenuItems = {};
  bool showAllCategories = true; // Track if "All" is selected
  late final KitchenMenuFilter _menuFilter = KitchenMenuFilter(
    Get.find<MenuCacheService>(),
  );
  bool _showTableAllOrders = true;
  bool _showServeOrderScreen = false;
  bool _showPreparationView = false;

  /// 0 = active (unserved items), 1 = served items only
  int _kitchenOrderTabIndex = 0;

  /// 0 = All, 1 = Table (dine-in), 2 = Take Away, 3 = Zomato
  int _orderTypeFilterIndex = 0;
  /// When false, Zomato orders are hidden from the All tab only.
  bool _showZomatoOrdersInAll = true;
  bool _mobileLayoutIsGrid = false;

  void _onBackgroundRingtoneSettingChanged() {
    _configureAudioPlayers();
    unawaited(
      KitchenBackgroundAlertService.syncMonitoringEnabled(
        KitchenSettings.backgroundOrderRingtoneEnabled.value,
      ),
    );
    if (!_canRingBell) {
      _stopAllKitchenSounds();
    }
  }

  void _onKitchenSettingsChanged() {
    if (!mounted) return;
    final layoutChanged =
        _mobileLayoutIsGrid != KitchenSettings.mobileOrdersGridLayout.value;
    _setStatePreservingScroll(() {
      _showTableAllOrders = KitchenSettings.showTableAllOrders.value == true;
      _showServeOrderScreen =
          KitchenSettings.showServeOrderScreen.value == true;
      _showPreparationView =
          KitchenSettings.preparationViewEnabled.value == true;
      _mobileLayoutIsGrid = KitchenSettings.mobileOrdersGridLayout.value;
      if (!_showServeOrderScreen) {
        _kitchenOrderTabIndex = 0;
        _itemSelection.cancel();
      }
      if (_showPreparationView) {
        _itemSelection.cancel();
      }
      if (!layoutChanged) {
        _rebuildDisplayFromCache();
      }
    });
  }

  bool get _useWebBackgroundAlert =>
      kIsWeb &&
      KitchenSettings.backgroundOrderRingtoneEnabled.value &&
      _isAppInBackground;

  Future<void> _playWebKitchenBell(KitchenBellSound sound) async {
    if (_useWebBackgroundAlert || _useAndroidLockedAlert) {
      await KitchenBackgroundAlertService.playAlert(sound);
      return;
    }
    await KitchenWebBellService.play(sound);
  }

  bool get _useAndroidLockedAlert =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      KitchenSettings.backgroundOrderRingtoneEnabled.value &&
      _isAppInBackground;

  void _playNotificationSound() async {
    if (!_canRingBell) return;
    if (kIsWeb) {
      await _playWebKitchenBell(KitchenBellSound.newOrder);
      return;
    }
    if (_useAndroidLockedAlert) {
      await KitchenBackgroundAlertService.playAlert(KitchenBellSound.newOrder);
      return;
    }
    try {
      await _preparePlayersForRing();
      await audioPlayer.stop();
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

    if (kIsWeb) {
      await _playWebKitchenBell(KitchenBellSound.delete);
      return;
    }
    if (_useAndroidLockedAlert) {
      await KitchenBackgroundAlertService.playAlert(KitchenBellSound.delete);
      return;
    }

    try {
      await _preparePlayersForRing();
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

    previousKeys = currentKeys;
    _previousSignatures = currentSignatures;
    _previousDocIds = currentDocIds;
    _previousKeyToGroup = keyToGroup;

    if (shouldPlay && _canRingBell) {
      _playDeleteSound();
    }
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
    if (kIsWeb) {
      await _playWebKitchenBell(KitchenBellSound.update);
      return;
    }
    if (_useAndroidLockedAlert) {
      await KitchenBackgroundAlertService.playAlert(KitchenBellSound.update);
      return;
    }
    try {
      await _preparePlayersForRing();
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
    required bool isPriority,
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
    final groupItemCounters = <int, int>{};

    for (final raw in itemsFromDb) {
      final itemMap = TableItemServed.asItemMap(raw);
      if (itemMap == null) continue;

      final groupIndex = TableItemServed.parseGroupIndex(itemMap['groupIndex']);
      final indexInGroup = groupItemCounters[groupIndex] ?? 0;
      groupItemCounters[groupIndex] = indexInGroup + 1;
      final Timestamp addedAt = (itemMap['addedAt'] is Timestamp)
          ? itemMap['addedAt'] as Timestamp
          : Timestamp.now();

      final normalized = Map<String, dynamic>.from(itemMap);
      normalized.remove('groupIndex');
      normalized.remove('addedAt');
      normalized['__firestoreGroupIndex'] = groupIndex;
      normalized['__itemIndex'] = indexInGroup;

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
          isPriority: isPriority,
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
          isPriority: isPriority,
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
    if (state == AppLifecycleState.resumed &&
        Get.isRegistered<SharedTablesSnapshotService>()) {
      Get.find<SharedTablesSnapshotService>().restart();
    }
    if (KitchenSettings.backgroundOrderRingtoneEnabled.value &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden)) {
      unawaited(_configureAudioPlayers());
    }
    if (!_canRingBell) {
      _stopAllKitchenSounds();
    }
  }

  @override
  void didUpdateWidget(KitchenOrdersListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canRingBell) {
      _stopAllKitchenSounds();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initAudioPlayers());
    if (kIsWeb) {
      unawaited(KitchenWebBellService.ensureInitialized());
    }
    KitchenSettings.load().then((_) async {
      await Get.find<MenuCacheService>().loadFromCacheOnly();
      _menuFilter.invalidate();
      await _initAudioPlayers();
      if (mounted) {
        setState(() {
          _showTableAllOrders =
              KitchenSettings.showTableAllOrders.value == true;
          _showServeOrderScreen =
              KitchenSettings.showServeOrderScreen.value == true;
          _showPreparationView =
              KitchenSettings.preparationViewEnabled.value == true;
          _mobileLayoutIsGrid =
              KitchenSettings.mobileOrdersGridLayout.value == true;
          showAllCategories = KitchenSettings.showAllCategories;
          selectedCategories = Set<String>.from(
            KitchenSettings.selectedCategories,
          );
          selectedMenuItems = Set<String>.from(
            KitchenSettings.selectedMenuItems,
          );
          _orderTypeFilterIndex = KitchenSettings.orderTypeFilterIndex;
          _showZomatoOrdersInAll = KitchenSettings.showZomatoOrdersInAll;
          _rebuildDisplayFromCache();
        });
      }
    });
    KitchenSettings.showTableAllOrders.addListener(_onKitchenSettingsChanged);
    KitchenSettings.showServeOrderScreen.addListener(_onKitchenSettingsChanged);
    KitchenSettings.preparationViewEnabled.addListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.mobileOrdersGridLayout.addListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.backgroundOrderRingtoneEnabled.addListener(
      _onBackgroundRingtoneSettingChanged,
    );
    _listenToKitchenTables();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _minuteTick.value++;
      _triggerDelayedBlinkIfNeeded();
    });
    _menuCacheListener = _onMenuCacheRevisionChanged;
    Get.find<MenuCacheService>().revisionListenable.addListener(
      _menuCacheListener!,
    );
  }

  void _onMenuCacheRevisionChanged() {
    if (!mounted) return;
    _menuFilter.invalidate();
    _setStatePreservingScroll(_rebuildDisplayFromCache);
  }

  void _listenToKitchenTables() {
    Get.find<SharedTablesSnapshotService>().subscribe(
      this,
      _handleTablesSnapshot,
    );
  }

  Future<void> _refreshKitchenOrders() async {
    if (_isRefreshingKitchen || !mounted) return;

    _setStatePreservingScroll(() => _isRefreshingKitchen = true);
    try {
      final snapshot = await Get.find<TablesRepository>().fetchAllTablesFresh();
      if (!mounted) return;
      _handleTablesSnapshot(snapshot);
      Get.find<SharedTablesSnapshotService>().restart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh kitchen orders: $e')),
        );
      }
    } finally {
      if (mounted) {
        _setStatePreservingScroll(() => _isRefreshingKitchen = false);
      }
    }
  }

  bool get _hasActiveDisplayFilter =>
      _hasActiveCategoryFilter ||
      _orderTypeFilterIndex != 0 ||
      (!_showZomatoOrdersInAll && _orderTypeFilterIndex == 0);

  bool _ordersHiddenByDisplayFilter() {
    if (_lastUpdatedGroups.isEmpty) return false;
    if (_showTableAllOrders) {
      return _displayTableCards.isEmpty;
    }
    return _displayFilteredGroups.isEmpty;
  }

  Future<void> _resetKitchenFiltersToShowAll() async {
    _setStatePreservingScroll(() {
      showAllCategories = true;
      selectedCategories.clear();
      selectedMenuItems.clear();
      _orderTypeFilterIndex = 0;
      _showZomatoOrdersInAll = true;
      _rebuildDisplayFromCache();
    });
    await KitchenSettings.saveCategoryFilter(
      showAll: true,
      categories: const {},
      menuItems: const {},
    );
    await KitchenSettings.saveOrderTypeFilterIndex(0);
    await KitchenSettings.saveShowZomatoOrdersInAll(true);
  }

  Widget _buildFilterHintBanner() {
    return Material(
      color: KitchenTheme.filterBannerBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 18,
              color: KitchenTheme.filterBannerIcon,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Some orders may be hidden by kitchen filters.',
                style: TextStyle(
                  fontFamily: fontMulishRegular,
                  fontSize: 12,
                  color: KitchenTheme.filterBannerText,
                ),
              ),
            ),
            TextButton(
              onPressed: _resetKitchenFiltersToShowAll,
              style: TextButton.styleFrom(foregroundColor: KitchenTheme.accent),
              child: const Text(
                'Show all',
                style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rebuildDisplayFromCache() {
    final filtered = _applyKitchenDisplayFilters(_lastUpdatedGroups);
    _displayFilteredGroups = filtered;
    _displayTableCards = _mergeGroupsByTable(filtered);
    _rebuildCrossTablePendingIndex();
    _rebuildPreparationItemGroups(filtered);
    if (_showPreparationView && _orderTypeFilterIndex != 3) {
      _previousPrepItemLineTokens = _buildPreparationItemLineTokens(filtered);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _triggerDelayedBlinkIfNeeded();
    });
  }

  void _rebuildCrossTablePendingIndex() {
    if (_showServeOrderScreen && _kitchenOrderTabIndex == 1) {
      _crossTablePendingIndex = KitchenCrossTablePendingIndex.empty();
      return;
    }

    final lines = <KitchenCrossTablePendingLine>[];
    for (final group in _filterByOrderType(_lastUpdatedGroups)) {
      final batchTime = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
      for (final entry in group.items.asMap().entries) {
        final item = TableItemServed.asItemMap(entry.value);
        if (item == null || TableItemServed.isServed(item)) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        lines.add(
          KitchenCrossTablePendingLine(
            tableName: group.tableName,
            itemName: name,
            qty: KitchenCrossTablePendingIndex.itemQty(item),
            orderTime: batchTime,
            isZomato: group.isZomato,
            remarks: item['remarks']?.toString(),
            itemKey: TableItemServed.keyForItem(
              docId: group.docId,
              item: item,
              groupIndexFallback: group.groupIndex,
              itemIndexFallback: entry.key,
            ),
          ),
        );
      }
    }
    _crossTablePendingIndex = KitchenCrossTablePendingIndex.fromLines(lines);
  }

  List<KitchenPreparationSourceLine> _collectPreparationSourceLines(
    List<TableGroup> groups,
  ) {
    final lines = <KitchenPreparationSourceLine>[];
    for (final group in groups) {
      final batchTime = DateTime.fromMillisecondsSinceEpoch(group.groupTime);
      for (final entry in group.items.asMap().entries) {
        final item = TableItemServed.asItemMap(entry.value);
        if (item == null) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        lines.add(
          KitchenPreparationSourceLine(
            itemName: name,
            tableName: group.tableName,
            qty: KitchenCrossTablePendingIndex.itemQty(item),
            orderTime: batchTime,
            itemKey: TableItemServed.keyForItem(
              docId: group.docId,
              item: item,
              groupIndexFallback: group.groupIndex,
              itemIndexFallback: entry.key,
            ),
            isServed: TableItemServed.isServed(item),
            remarks: item['remarks']?.toString(),
            isZomato: group.isZomato,
          ),
        );
      }
    }
    return lines;
  }

  Map<String, Set<String>> _buildPreparationItemLineTokens(
    List<TableGroup> groups,
  ) {
    final itemGroups = KitchenPreparationViewIndex.fromLines(
      _collectPreparationSourceLines(groups),
    );
    final tokens = <String, Set<String>>{};
    for (final group in itemGroups) {
      final key = KitchenCrossTablePendingIndex.normalizeItemName(
        group.itemName,
      );
      tokens[key] = group.lines
          .map(
            (line) =>
                '${line.tableName}|${line.qty}|${line.remarks ?? ''}|${line.isServed}',
          )
          .toSet();
    }
    return tokens;
  }

  bool _shouldPlaySoundForPrepItem(String normalizedItemKey) {
    if (!_hasActiveCategoryFilter) return true;

    for (final group in _lastUpdatedGroups) {
      for (final raw in group.items) {
        final item = TableItemServed.asItemMap(raw);
        if (item == null) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        if (KitchenCrossTablePendingIndex.normalizeItemName(name) !=
            normalizedItemKey) {
          continue;
        }
        if (_isMenuItemIncludedInFilter(item)) {
          return true;
        }
      }
    }
    return false;
  }

  void _schedulePreparationItemBlink(
    Set<String> normalizedItemKeys, {
    required bool isUpdate,
    bool isServe = false,
  }) {
    if (normalizedItemKeys.isEmpty) return;

    _prepBlinkTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setStatePreservingScroll(() {
        _blinkingPrepItemKeys = Set<String>.from(normalizedItemKeys);
        _prepBlinkColor = isServe
            ? _serveBlinkColor
            : isUpdate
            ? _updateBlinkColor
            : _newOrderBlinkColor;
      });
      _prepBlinkTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _setStatePreservingScroll(() => _blinkingPrepItemKeys = {});
      });
    });
  }

  void _notifyPreparationItemsAffected(
    Set<String> normalizedItemKeys, {
    required bool isUpdate,
    bool isServe = false,
    String serveEventKey = '',
  }) {
    if (normalizedItemKeys.isEmpty) return;

    final shouldPlay = normalizedItemKeys.any(_shouldPlaySoundForPrepItem);
    if (shouldPlay && _canRingBell) {
      if (isServe) {
        final servedItemKeyIds = <String>{};
        for (final group in _lastUpdatedGroups) {
          final previous = _previousKeyToGroup[group.key];
          if (previous == null) continue;
          servedItemKeyIds.addAll(
            TableServeChangeUtils.newlyServedTableItemKeyIds(
              group.docId,
              previous.items,
              group.items,
            ),
          );
        }
        unawaited(
          Get.find<ServeNotificationService>().tryPlayServeAlert(
            eventKey: serveEventKey,
            kitchenEligible: true,
            dashboardEligible: false,
            servedItemKeyIds: servedItemKeyIds,
          ),
        );
      } else if (isUpdate) {
        _playUpdateSound();
      } else {
        _playNotificationSound();
      }
    }

    _schedulePreparationItemBlink(
      normalizedItemKeys,
      isUpdate: isUpdate,
      isServe: isServe,
    );
  }

  void _handlePreparationItemAlerts(List<TableGroup> filteredGroups) {
    final currentTokens = _buildPreparationItemLineTokens(filteredGroups);

    if (!_showPreparationView || _orderTypeFilterIndex == 3) {
      _previousPrepItemLineTokens = currentTokens;
      return;
    }

    if (_previousPrepItemLineTokens.isEmpty) {
      if (_wasKitchenEmpty && currentTokens.isNotEmpty) {
        _notifyPreparationItemsAffected(
          currentTokens.keys.toSet(),
          isUpdate: false,
        );
      }
      _previousPrepItemLineTokens = currentTokens;
      return;
    }

    final affected = <String>{};
    var anyNew = false;
    var anyUpdate = false;
    var anyServe = false;
    String serveEventKey = '';

    for (final entry in currentTokens.entries) {
      final previous = _previousPrepItemLineTokens[entry.key];
      if (previous == null) {
        affected.add(entry.key);
        anyNew = true;
        continue;
      }

      final addedLines = entry.value.difference(previous);
      if (addedLines.isNotEmpty) {
        affected.add(entry.key);
        if (TableServeChangeUtils.isServeOnlyPrepTokenChange(
          previous,
          entry.value,
        )) {
          anyServe = true;
          serveEventKey = 'prep:${entry.key}:${addedLines.join(';')}';
        } else {
          anyUpdate = true;
        }
      }
    }

    _previousPrepItemLineTokens = currentTokens;

    if (affected.isEmpty) return;

    _notifyPreparationItemsAffected(
      affected,
      isUpdate: anyUpdate && !anyNew && !anyServe,
      isServe: anyServe && !anyNew,
      serveEventKey: serveEventKey,
    );
  }

  void _rebuildPreparationItemGroups(List<TableGroup> groups) {
    if (!_showPreparationView) {
      _preparationItemGroups = [];
      return;
    }

    _preparationItemGroups = KitchenPreparationViewIndex.fromLines(
      _collectPreparationSourceLines(groups),
    );
  }

  bool get _usePreparationViewLayout =>
      _showPreparationView && _orderTypeFilterIndex != 3;

  List<TableGroup> get _preparationViewZomatoGroups {
    if (!_usePreparationViewLayout || _orderTypeFilterIndex != 0) {
      return const [];
    }
    return _displayFilteredGroups
        .where((group) => group.isZomato && _isScreenshotOnlyZomatoGroup(group))
        .toList();
  }

  bool _isScreenshotOnlyZomatoGroup(TableGroup group) {
    for (final raw in group.items) {
      final item = TableItemServed.asItemMap(raw);
      if (item == null) continue;
      if ((item['name']?.toString().trim() ?? '').isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  List<Widget> _buildPreparationViewZomatoFooterCards() {
    final zomatoGroups = _preparationViewZomatoGroups;
    if (zomatoGroups.isEmpty) return const [];

    final firstUnpaidIndex = _displayFilteredGroups.indexWhere(
      (g) => !g.isPaid,
    );
    final cards = <Widget>[];
    for (var i = 0; i < _displayFilteredGroups.length; i++) {
      final group = _displayFilteredGroups[i];
      if (!group.isZomato || !_isScreenshotOnlyZomatoGroup(group)) continue;
      cards.add(
        _buildGroupCard(
          group,
          i + 1,
          isNext: i == firstUnpaidIndex && firstUnpaidIndex != -1,
        ),
      );
    }
    return cards;
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
    if (_orderTypeFilterIndex == 0) {
      if (_showZomatoOrdersInAll) return groups;
      return groups.where((group) => !group.isZomato).toList();
    }
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
    _setStatePreservingScroll(() {
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
                copy['__itemIndex'] = TableItemServed.itemIndexInGroupFor(
                  item,
                  entry.key,
                );
                copy['__firestoreGroupIndex'] =
                    TableItemServed.firestoreGroupIndexFor(
                      item,
                      group.groupIndex,
                    );
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
            isPriority: group.isPriority,
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
    _setStatePreservingScroll(() {
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
                copy['__itemIndex'] = TableItemServed.itemIndexInGroupFor(
                  item,
                  entry.key,
                );
                copy['__firestoreGroupIndex'] =
                    TableItemServed.firestoreGroupIndexFor(
                      item,
                      group.groupIndex,
                    );
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
            isPriority: group.isPriority,
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
          a[i].isPriority != b[i].isPriority ||
          _groupSignature(a[i]) != _groupSignature(b[i])) {
        return false;
      }
    }
    return true;
  }

  bool _sameTableCards(List<KitchenTableCard> a, List<KitchenTableCard> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].docId != b[i].docId ||
          a[i].isPaid != b[i].isPaid ||
          a[i].isPriority != b[i].isPriority) {
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
        _previousPrepItemLineTokens = {};
      }
      if (_displayFilteredGroups.isNotEmpty ||
          _displayTableCards.isNotEmpty ||
          _preparationItemGroups.isNotEmpty ||
          !_kitchenStreamReady) {
        _setStatePreservingScroll(() {
          _lastUpdatedGroups = [];
          _displayFilteredGroups = [];
          _displayTableCards = [];
          _crossTablePendingIndex = KitchenCrossTablePendingIndex.empty();
          _preparationItemGroups = [];
          _blinkingPrepItemKeys = {};
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
      final isPriority = data['kitchenPriority'] == true;
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
          isPriority: isPriority,
          lastTransactionId: lastTransactionId,
          source: source,
          screenshotUrl: screenshotUrl,
          zomatoStatus: zomatoStatus,
          createdAt: createdAt is Timestamp ? createdAt : null,
        ),
      );
    }

    updatedGroups.sort(_compareKitchenOrdersByPriorityAndTime);
    _lastUpdatedGroups = updatedGroups;
    _rebuildCrossTablePendingIndex();

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
        final serveKeys = <String>[];
        final editKeys = <String>[];
        String serveEventKey = '';

        for (final key in updateKeys) {
          final previous = _previousKeyToGroup[key];
          final current = keyToGroup[key];
          if (previous != null &&
              current != null &&
              TableServeChangeUtils.isServeOnlyItemsChange(
                previous.items,
                current.items,
              )) {
            serveKeys.add(key);
            final docId = current.docId;
            final servedItemKeyIds =
                TableServeChangeUtils.newlyServedTableItemKeyIds(
                  docId,
                  previous.items,
                  current.items,
                );
            serveEventKey = TableServeChangeUtils.eventKeyForDoc(
              docId,
              servedItemKeyIds,
            );
          } else {
            editKeys.add(key);
          }
        }

        if (serveKeys.isNotEmpty) {
          _scheduleServeBlink(
            key: serveKeys.last,
            keyToGroup: keyToGroup,
            currentKeys: currentKeys,
            currentSignatures: currentSignatures,
            currentDocIds: currentDocIds,
            serveEventKey: serveEventKey,
          );
        } else if (editKeys.isNotEmpty) {
          _scheduleItemHighlightsForUpdates(
            groupKeys: editKeys,
            keyToGroup: keyToGroup,
          );
          _scheduleBlink(
            key: editKeys.last,
            keyToGroup: keyToGroup,
            currentKeys: currentKeys,
            currentSignatures: currentSignatures,
            currentDocIds: currentDocIds,
            isUpdate: true,
          );
        }
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

    _handlePreparationItemAlerts(filteredGroups);

    final displayChanged = _showTableAllOrders
        ? !_sameTableCards(_displayTableCards, tableCards)
        : !_sameGroupList(_displayFilteredGroups, filteredGroups);

    if (displayChanged || !_kitchenStreamReady) {
      _setStatePreservingScroll(() {
        _displayFilteredGroups = filteredGroups;
        _displayTableCards = tableCards;
        _rebuildPreparationItemGroups(filteredGroups);
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
    if (!_showZomatoOrdersInAll && _orderTypeFilterIndex == 0) {
      return 'No table or take away orders found';
    }
    return 'No orders found$typeSuffix';
  }

  Widget _buildKitchenEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasActiveDisplayFilter
                ? Icons.filter_list_off
                : Icons.inbox_outlined,
            size: 64,
            color: KitchenTheme.accentMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _emptyStateMessage(),
            style: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 16,
              color: KitchenTheme.accentMuted,
            ),
          ),
          if (_hasActiveDisplayFilter) ...[
            const SizedBox(height: 8),
            Text(
              selectedCategories.isNotEmpty
                  ? "Selected: ${selectedCategories.join(', ')}"
                  : !_showZomatoOrdersInAll &&
                        _orderTypeFilterIndex == 0 &&
                        !_hasActiveCategoryFilter
                  ? 'Zomato orders are hidden from All'
                  : 'Selected menu items filter is active',
              style: const TextStyle(
                fontFamily: fontMulishRegular,
                fontSize: 14,
                color: KitchenTheme.surfaceBorder,
              ),
              textAlign: TextAlign.center,
            ),
            // const SizedBox(height: 12),
            // OutlinedButton.icon(
            //   onPressed: _resetKitchenFiltersToShowAll,
            //   icon: const Icon(Icons.filter_list_off, size: 18),
            //   label: const Text(
            //     'Show all orders',
            //     style: TextStyle(fontFamily: fontMulishSemiBold),
            //   ),
            // ),
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

  Widget _buildKitchenScrollContent() {
    final zomatoFooterCards = _buildPreparationViewZomatoFooterCards();
    final isEmpty = _usePreparationViewLayout
        ? _preparationItemGroups.isEmpty && zomatoFooterCards.isEmpty
        : _showTableAllOrders
        ? _displayTableCards.isEmpty
        : _displayFilteredGroups.isEmpty;

    if (isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: _buildKitchenEmptyState(),
          ),
        ],
      );
    }

    if (_usePreparationViewLayout) {
      final screenW = MediaQuery.sizeOf(context).width;
      final layoutIsGrid = _mobileLayoutIsGrid;
      final crossCols = layoutIsGrid ? _kitchenCrossAxisCount(screenW) : 1;
      return KitchenPreparationOrdersList(
        key: ValueKey(
          'kitchen_prep_${_kitchenOrderTabIndex}_$_orderTypeFilterIndex'
          '_${layoutIsGrid ? 'grid' : 'list'}_$crossCols',
        ),
        groups: _preparationItemGroups,
        footerChildren: zomatoFooterCards,
        scrollController: _gridScrollController,
        formatRelativeTime: formatRelativeTime,
        minuteTick: _minuteTick,
        layoutIsGrid: layoutIsGrid,
        crossAxisCount: crossCols,
        mainAxisSpacing: _kitchenMainAxisSpacing,
        crossAxisSpacing: _kitchenCrossAxisSpacing,
        padding: _kitchenGridPadding,
        servedTabActive: _showServeOrderScreen && _kitchenOrderTabIndex == 1,
        blinkingItemKeys: _blinkingPrepItemKeys,
        blinkColor: _prepBlinkColor,
      );
    }

    return _buildKitchenOrdersGrid();
  }

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
        controller: _gridScrollController,
        restorationId: 'kitchen_orders_grid',
        cacheExtent: 3000,
        physics: const AlwaysScrollableScrollPhysics(),
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
      controller: _gridScrollController,
      restorationId: 'kitchen_orders_grid',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
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
        controller: _gridScrollController,
        restorationId: 'kitchen_orders_list',
        cacheExtent: 3000,
        physics: const AlwaysScrollableScrollPhysics(),
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
      controller: _gridScrollController,
      restorationId: 'kitchen_orders_list',
      cacheExtent: 3000,
      physics: const AlwaysScrollableScrollPhysics(),
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
          isPriority: group.isPriority,
          lastTransactionId: group.lastTransactionId,
          batches: [group],
        );
      } else {
        map[group.docId]!.batches.add(group);
        if (group.isPaid) map[group.docId]!.isPaid = true;
        if (group.isPriority) map[group.docId]!.isPriority = true;
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
      ..sort(_compareKitchenTableCardsByPriorityAndTime);
    return cards;
  }

  int _compareKitchenOrdersByPriorityAndTime(TableGroup a, TableGroup b) {
    if (a.isPriority != b.isPriority) {
      return a.isPriority ? -1 : 1;
    }
    return a.groupTime.compareTo(b.groupTime);
  }

  int _compareKitchenTableCardsByPriorityAndTime(
    KitchenTableCard a,
    KitchenTableCard b,
  ) {
    if (a.isPriority != b.isPriority) {
      return a.isPriority ? -1 : 1;
    }
    return a.batches.first.groupTime.compareTo(b.batches.first.groupTime);
  }

  bool get _hasActiveCategoryFilter => _menuFilter.hasActiveFilter(
    showAllCategories: showAllCategories,
    selectedCategories: selectedCategories,
    selectedMenuItems: selectedMenuItems,
  );

  bool _isMenuItemIncludedInFilter(Map<String, dynamic> item) {
    return _menuFilter.matchesOrderItem(
      item: item,
      showAllCategories: showAllCategories,
      selectedCategories: selectedCategories,
      selectedMenuItems: selectedMenuItems,
    );
  }

  String _menuItemFilterKey(String category, String itemName) =>
      KitchenMenuFilter.filterKey(category, itemName);

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
      if (selectedMenuItems.contains(
        _menuItemFilterKey(categoryName, itemName),
      )) {
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

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyFilterChanges() {
              setDialogState(() {});
              _applyCategoryFilterChanges();
            }

            void applyZomatoFilterChange(bool value) {
              setDialogState(() => _showZomatoOrdersInAll = value);
              _setStatePreservingScroll(_rebuildDisplayFromCache);
              unawaited(KitchenSettings.saveShowZomatoOrdersInAll(value));
            }

            Widget zomatoFilterTile() {
              return CheckboxListTile(
                title: const Text(
                  'Show Zomato Orders',
                  style: TextStyle(
                    fontFamily: fontMulishSemiBold,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'Applies to the All tab only',
                  style: TextStyle(
                    fontFamily: fontMulishRegular,
                    fontSize: 12,
                  ),
                ),
                value: _showZomatoOrdersInAll,
                activeColor: Colors.green,
                onChanged: (bool? value) {
                  applyZomatoFilterChange(value ?? true);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }

            if (categoryNames.isEmpty) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  "Filter by Category",
                  style: TextStyle(fontFamily: fontMulishSemiBold, fontSize: 18),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    zomatoFilterTile(),
                    const Divider(),
                    const Text(
                      'No menu categories in cache. Open Menu and tap Refresh to load the menu.',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Close"),
                  ),
                ],
              );
            }

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
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    zomatoFilterTile(),
                    const Divider(),
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
    _setStatePreservingScroll(_rebuildDisplayFromCache);
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
                copy['__itemIndex'] = TableItemServed.itemIndexInGroupFor(
                  item,
                  entry.key,
                );
                copy['__firestoreGroupIndex'] =
                    TableItemServed.firestoreGroupIndexFor(
                      item,
                      group.groupIndex,
                    );
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
            isPriority: group.isPriority,
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
    _setStatePreservingScroll(() => _mobileLayoutIsGrid = isGrid);
    KitchenSettings.setMobileOrdersGridLayout(isGrid);
  }

  Widget _buildMobileLayoutToggle() {
    final showingGrid = _mobileLayoutIsGrid;
    return IconButton(
      icon: Icon(
        showingGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
        size: 22,
      ),
      tooltip: showingGrid
          ? 'Switch to list view'
          : _isTabletKitchenScreen
          ? 'Switch to grid view (responsive columns)'
          : 'Switch to grid view (2 columns)',
      onPressed: () => _setMobileLayoutIsGrid(!showingGrid),
    );
  }

  Widget _buildKitchenOrderTabs() {
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
                  color: selected ? KitchenTheme.accent : Colors.transparent,
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
                color: selected
                    ? KitchenTheme.textOnDark
                    : KitchenTheme.textOnDarkMuted,
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: KitchenTheme.surface,
      child: Row(
        children: [tabButton('All Orders', 0), tabButton('Served Orders', 1)],
      ),
    );
  }

  Widget _buildOrderTypeFilter() {
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
                  activeColor: KitchenTheme.accent,
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return KitchenTheme.accent;
                    }
                    return KitchenTheme.accentMuted;
                  }),
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
                      color: selected
                          ? KitchenTheme.textOnDark
                          : KitchenTheme.accentMuted,
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
      color: KitchenTheme.surfaceElevated,
      elevation: 0,
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
      backgroundColor: KitchenTheme.bg,
      appBar: AppBar(
        backgroundColor: KitchenTheme.surface,
        foregroundColor: KitchenTheme.textOnDark,
        elevation: 0,
        title: const Text(
          "Kitchen",
          style: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 16,
            color: KitchenTheme.textOnDark,
          ),
        ),
        bottom: _showServeOrderScreen
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _buildKitchenOrderTabs(),
              )
            : null,
        actions: [
          const FirestoreSyncStatusChip(channel: FirestoreSyncChannel.kitchen),
          IconButton(
            icon: _isRefreshingKitchen
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh orders',
            onPressed: _isRefreshingKitchen ? null : _refreshKitchenOrders,
          ),
          if (_usePreparationViewLayout || _isMobileKitchenScreen)
            _buildMobileLayoutToggle(),
          // Filter button with badge showing count
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showCategoryFilterDialog(context),
                tooltip: "Filter by Category",
              ),
              if ((!showAllCategories && selectedCategories.isNotEmpty) ||
                  !_showZomatoOrdersInAll)
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
                        selectedCategories.isNotEmpty
                            ? '${selectedCategories.length}'
                            : '!',
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
          ? const Center(
              child: CircularProgressIndicator(color: KitchenTheme.accent),
            )
          : Column(
              children: [
                if (_isRefreshingKitchen)
                  const LinearProgressIndicator(
                    minHeight: 3,
                    color: KitchenTheme.accent,
                    backgroundColor: Color(0x26F57C35),
                  ),
                _buildOrderTypeFilter(),
                if (_hasActiveDisplayFilter && _ordersHiddenByDisplayFilter())
                  _buildFilterHintBanner(),
                Expanded(
                  child: RefreshIndicator(
                    color: KitchenTheme.accent,
                    backgroundColor: KitchenTheme.surfaceElevated,
                    onRefresh: _refreshKitchenOrders,
                    child: _buildKitchenScrollContent(),
                  ),
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
    final isDelayedBlinking = _isDelayedGroupBlinking(group);

    return _wrapWithPriorityGestures(
      docId: group.docId,
      tableName: group.tableName,
      isPriority: group.isPriority,
      child: KeyedSubtree(
        key: ValueKey(group.key),
        child: ListenableBuilder(
          listenable: _minuteTick,
          builder: (context, _) {
            final tickTime = DateTime.fromMillisecondsSinceEpoch(
              group.groupTime,
            );
            final tickIsDelayed = _isOrderDelayed(tickTime);
            final headerColor = KitchenTheme.headerForOrderTable(
              group.tableName,
              isZomato: group.isZomato,
              isDelayed: tickIsDelayed,
            );
            return _orderCardShell(
              isBlinking: isBlinking,
              animationDuration: const Duration(milliseconds: 800),
              decoration: _orderCardDecoration(
                isBlinking,
                headerColor,
                isNext: isNext,
                isPriority: group.isPriority,
                compact: _isMobileGridLayout,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOrderHeader(
                    group.tableName,
                    group.isPaid,
                    queueNumber,
                    headerColor: headerColor,
                    isZomato: group.isZomato,
                    isNext: isNext,
                    isPriority: group.isPriority,
                    onPaidHeaderTap: group.isZomato &&
                            MarkAsDeliveredPermission.canMarkAsDelivered
                        ? () => _markTableServed(
                              group.tableName,
                              group.docId,
                              lastTransactionId: group.lastTransactionId,
                            )
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
                          final selectionMode = _itemSelection
                              .isSelectionModeFor(group.docId);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...group.items.asMap().entries.map(
                                (entry) => _buildItemRow(
                                  entry.value,
                                  docId: group.docId,
                                  groupIndex:
                                      TableItemServed.firestoreGroupIndexFor(
                                        entry.value,
                                        group.groupIndex,
                                      ),
                                  itemIndexInGroup:
                                      TableItemServed.itemIndexInGroupFor(
                                        entry.value,
                                        entry.key,
                                      ),
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

    return _wrapWithPriorityGestures(
      docId: tableCard.docId,
      tableName: tableCard.tableName,
      isPriority: tableCard.isPriority,
      child: KeyedSubtree(
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
            final headerColor = KitchenTheme.headerForOrderTable(
              tableCard.tableName,
              isZomato: isZomato,
              isDelayed: tickIsDelayed,
            );
            return _orderCardShell(
              isBlinking: isBlinking,
              decoration: _orderCardDecoration(
                isBlinking,
                headerColor,
                isNext: isNext,
                isPriority: tableCard.isPriority,
                compact: _isMobileGridLayout,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOrderHeader(
                    tableCard.tableName,
                    tableCard.isPaid,
                    queueNumber,
                    headerColor: headerColor,
                    isZomato: isZomato,
                    isNext: isNext,
                    isPriority: tableCard.isPriority,
                    onPaidHeaderTap: isZomato &&
                            MarkAsDeliveredPermission.canMarkAsDelivered
                        ? () => _markTableServed(
                              tableCard.tableName,
                              tableCard.docId,
                              lastTransactionId: tableCard.lastTransactionId,
                            )
                        : null,
                    compact: _isMobileGridLayout,
                  ),
                  if (isZomato &&
                      zomatoGroup != null &&
                      (zomatoGroup.screenshotUrl?.isNotEmpty ?? false)) ...[
                    _buildTimeBar(
                      DateTime.fromMillisecondsSinceEpoch(
                        zomatoGroup.groupTime,
                      ),
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
                        listenable: _itemSelection.listenableFor(
                          tableCard.docId,
                        ),
                        builder: (context, _) {
                          final selectionMode = _itemSelection
                              .isSelectionModeFor(tableCard.docId);
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
                                      dashColor: KitchenTheme.surfaceBorder,
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
                                                  ? KitchenTheme.delayedText
                                                  : KitchenTheme.accentMuted,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ...batch.items.asMap().entries.map(
                                          (entry) => _buildItemRow(
                                            entry.value,
                                            docId: tableCard.docId,
                                            groupIndex:
                                                TableItemServed.firestoreGroupIndexFor(
                                                  entry.value,
                                                  batch.groupIndex,
                                                ),
                                            itemIndexInGroup:
                                                TableItemServed.itemIndexInGroupFor(
                                                  entry.value,
                                                  entry.key,
                                                ),
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
      ),
    );
  }


  String? _currentCompletedByName() {
    if (!Get.isRegistered<RestaurantSession>()) return null;
    final profile = Get.find<RestaurantSession>().profile.value;
    if (profile == null) return null;
    final name = profile.name?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : profile.email.trim();
    if (displayName.isEmpty) return null;
    return displayName;
  }

  Future<void> _recordCompletedBy({
    String? lastTransactionId,
    String? completedBy,
  }) async {
    final name = completedBy?.trim();
    if (name == null || name.isEmpty) return;
    final txId = lastTransactionId?.trim();
    if (txId == null || txId.isEmpty) return;
    try {
      await Get.find<TransactionsRepository>().setCompletedBy(
        transactionId: txId,
        completedBy: name,
      );
    } catch (_) {
      // Best-effort - do not block serve/clear flow.
    }
  }

  void _markTableServed(
    String tableName,
    String docId, {
    String? lastTransactionId,
  }) {
    if (selectedCategories.isNotEmpty && !showAllCategories) return;
    if (!MarkAsDeliveredPermission.canMarkAsDelivered) return;
    showServedDialog(context, tableName, () async {
      _playDeleteSound();
      await _clearKitchenPriority(docId);
      final completedBy = _currentCompletedByName();
      if (ZomatoOrderUtils.isZomatoOrderName(tableName)) {
        try {
          await Get.find<ZomatoOrderServeService>().serveOrder(
            docId: docId,
            completedBy: completedBy,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Zomato order served.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not mark as served: $e')),
            );
          }
        }
      } else if (isDiningTableName(tableName)) {
        await _recordCompletedBy(
          lastTransactionId: lastTransactionId,
          completedBy: completedBy,
        );
        await _updateTableItemsInFirestore(tableName, [], false);
      } else {
        await _recordCompletedBy(
          lastTransactionId: lastTransactionId,
          completedBy: completedBy,
        );
        await FirestorePaths.scoped('tables').doc(docId).delete();
      }
    });
  }
  BoxDecoration _orderCardDecoration(
    bool isBlinking,
    Color headerColor, {
    bool isNext = false,
    bool isPriority = false,
    bool compact = false,
  }) {
    final radius = compact ? 8.0 : 12.0;
    final borderWidth = isPriority
        ? (compact ? 2.0 : 2.5)
        : compact
        ? (isNext ? 2.0 : 1.5)
        : (isNext ? 2.5 : 1.0);
    final borderColor = isPriority
        ? const Color(0xFFD32F2F)
        : isNext
        ? headerColor
        : Colors.grey.shade200.withValues(alpha: 0.85);
    return BoxDecoration(
      color: isBlinking ? _blinkColor : KitchenTheme.cardBody,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: KitchenTheme.cardShadows(
        accentColor: isPriority ? const Color(0xFFD32F2F) : headerColor,
        emphasize: isNext || isPriority,
        compact: compact,
      ),
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }

  Widget _wrapWithPriorityGestures({
    required String docId,
    required String tableName,
    required bool isPriority,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showKitchenPriorityDialog(
        docId: docId,
        tableName: tableName,
        isPriority: isPriority,
      ),
      onDoubleTap: () => _showKitchenPriorityDialog(
        docId: docId,
        tableName: tableName,
        isPriority: isPriority,
      ),
      child: child,
    );
  }

  Future<void> _showKitchenPriorityDialog({
    required String docId,
    required String tableName,
    required bool isPriority,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isPriority ? 'Remove priority?' : 'Set priority?',
            style: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 18,
            ),
          ),
          content: Text(
            isPriority
                ? 'Remove the priority tag from "$tableName"?'
                : 'Mark "$tableName" as priority for the kitchen?',
            style: const TextStyle(fontFamily: fontMulishRegular, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: fontMulishSemiBold,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPriority
                    ? Colors.grey.shade700
                    : KitchenTheme.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                isPriority ? 'Remove Priority' : 'Set Priority',
                style: const TextStyle(fontFamily: fontMulishSemiBold),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _setKitchenPriority(docId, !isPriority);
  }

  Future<void> _setKitchenPriority(String docId, bool isPriority) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isPriority) {
        updates['kitchenPriority'] = true;
      } else {
        updates['kitchenPriority'] = FieldValue.delete();
      }
      await FirestorePaths.scoped('tables').doc(docId).update(updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update priority: $e')));
    }
  }

  Future<void> _clearKitchenPriority(String docId) async {
    try {
      await FirestorePaths.scoped('tables').doc(docId).update({
        'kitchenPriority': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Priority may already be absent when the table document is deleted.
    }
  }

  Widget _priorityRibbonTag({required bool compact, required bool isZomato}) {
    final size = compact ? 18.0 : 20.0;
    return SvgPicture.asset(
      isZomato
          ? 'assets/images/priority_icon_white.svg'
          : 'assets/images/priority_icon.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _buildOrderHeader(
    String tableName,
    bool isPaid,
    int queueNumber, {
    required Color headerColor,
    bool isZomato = false,
    bool isNext = false,
    bool isPriority = false,
    VoidCallback? onPaidHeaderTap,
    VoidCallback? onPaidDoubleTap,
    bool compact = false,
  }) {
    final paid = isPaid == true;
    final zomato = isZomato || ZomatoOrderUtils.isZomatoOrderName(tableName);
    final isTakeAway = isTakeAwayOrderName(tableName);
    final titleColor = KitchenTheme.headerTitleColor(headerColor);
    final header = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: headerColor,
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
                    isTakeAway ? icon_packing : icon_table,
                    colorFilter: ColorFilter.mode(titleColor, BlendMode.srcIn),
                    width: isTakeAway
                        ? (compact ? 15 : 18)
                        : (compact ? 18 : 22),
                  ),
                SizedBox(width: compact ? 6 : 8),
                Flexible(
                  child: Text(
                    tableName,
                    style: TextStyle(
                      fontFamily: zomato || isTakeAway
                          ? fontMulishBold
                          : fontMulishSemiBold,
                      fontSize: compact ? 13 : 16,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPriority) ...[
                  SizedBox(width: compact ? 4 : 6),
                  _priorityRibbonTag(compact: compact, isZomato: zomato),
                ],
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

          if (!isPriority)
            Container(
              margin: const EdgeInsets.only(right: 0),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$queueNumber',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontFamily: fontMulishBold,
                  height: 1,
                ),
              ),
            ),

          // if (isNext)
          //   Container(
          //     margin: const EdgeInsets.only(left: 8),
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     decoration: BoxDecoration(
          //       border: Border.all(color: Colors.black12, width: 1.2),
          //       borderRadius: BorderRadius.circular(4),
          //       color: Colors.white.withValues(alpha: 0.15),
          //     ),
          //     child: const Text(
          //       "NEXT",
          //       style: TextStyle(
          //         color: Colors.black,
          //         fontSize: 10,
          //         fontFamily: fontMulishBold,
          //       ),
          //     ),
          //   ),
          if (paid)
            GestureDetector(
              onDoubleTap: onPaidDoubleTap,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: KitchenTheme.servedGreen,
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
      color: isDelayed ? _delayedItemBackground : const Color(0xFFF0F4F8),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: isDelayed
                ? KitchenTheme.delayedIcon
                : KitchenTheme.accentMuted,
          ),
          const SizedBox(width: 6),
          _KitchenRelativeTime(
            time: time,
            tick: _minuteTick,
            formatter: formatRelativeTime,
            style: TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 13,
              color: isDelayed
                  ? KitchenTheme.delayedText
                  : const Color(0xFF475569),
            ),
          ),
          if (isDelayed) ...[
            const Spacer(),
            const Text(
              "DELAYED",
              style: TextStyle(
                color: KitchenTheme.delayedText,
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
    final itemName = item['name']?.toString() ?? '';
    final pendingSummary =
        (!served &&
            !_showPreparationView &&
            !(_showServeOrderScreen && _kitchenOrderTabIndex == 1))
        ? _crossTablePendingIndex.summaryForItemName(itemName)
        : null;
    final showCrossTableBadge =
        pendingSummary != null && pendingSummary.spansMultipleTables;
    final highlightKind = _highlightedItemKinds[key.id];

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
      crossTablePendingTotal: showCrossTableBadge
          ? pendingSummary!.totalQty
          : null,
      onCrossTablePendingTap: showCrossTableBadge
          ? () => KitchenCrossTablePendingSheet.show(
              context,
              summary: pendingSummary!,
              formatRelativeTime: formatRelativeTime,
            )
          : null,
    );

    if (highlightKind != null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _newItemHighlightColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: row,
      );
    }

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
    if (_menuCacheListener != null) {
      Get.find<MenuCacheService>().revisionListenable.removeListener(
        _menuCacheListener!,
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    KitchenSettings.showTableAllOrders.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.showServeOrderScreen.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.preparationViewEnabled.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.mobileOrdersGridLayout.removeListener(
      _onKitchenSettingsChanged,
    );
    KitchenSettings.backgroundOrderRingtoneEnabled.removeListener(
      _onBackgroundRingtoneSettingChanged,
    );
    if (Get.isRegistered<SharedTablesSnapshotService>()) {
      Get.find<SharedTablesSnapshotService>().unsubscribe(this);
    }
    _gridScrollController.dispose();
    _timer?.cancel();
    _delayedBlinkTimer?.cancel();
    _prepBlinkTimer?.cancel();
    _itemHighlightTimer?.cancel();
    _minuteTick.dispose();
    audioPlayer.dispose();
    updateAudioPlayer.dispose();
    deleteAudioPlayer.dispose();
    super.dispose();
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

enum _KitchenItemHighlightKind { newItem, edited }

class TableGroup {
  final String tableName;
  final List<Map<String, dynamic>> items;
  final int groupTime;
  final String key;
  final String docId;
  final bool isPaid;
  final bool isPriority;
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
    this.isPriority = false,
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
  bool isPriority;
  String? lastTransactionId;
  final List<TableGroup> batches;

  KitchenTableCard({
    required this.tableName,
    required this.docId,
    required this.isPaid,
    this.isPriority = false,
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
