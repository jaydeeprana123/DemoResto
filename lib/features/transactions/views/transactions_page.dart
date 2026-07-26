import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/core/firestore/firestore_paths.dart';
import 'package:demo/features/transactions/services/transaction_bill_service.dart';
import 'package:demo/features/transactions/views/transaction_details_page.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/Styles/my_icons.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime? fromDate;
  DateTime? toDate;

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String _searchQuery = '';

  double grandTotal = 0.0;
  double grandTotalOnline = 0.0;
  double grandTotalCash = 0.0;
  double grandTotalDiscount = 0.0;
  int totalTransactionsData = 0;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions = [];
  bool isLoading = false;
  bool hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

  final ScrollController _scrollController = ScrollController();
  static const int pageSize = 10;

  @override
  void initState() {
    super.initState();
    _setDefaultTodayRange();
    _applyFilter(); // today's range: Firestore query + totals from that range only
    _scrollController.addListener(_scrollListener);
  }

  /// Default From/To to start and end of today so the page never loads all-time data.
  void _setDefaultTodayRange() {
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    toDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    fromController.text = _dateTimeLabelFormat.format(fromDate!);
    toController.text = _dateTimeLabelFormat.format(toDate!);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredTransactions {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return transactions;
    return transactions.where((doc) {
      final data = doc.data();
      final billId = TransactionBillService.displayBillId(
        data,
        documentId: doc.id,
      ).toLowerCase();
      final table = (data['table'] ?? '').toString().toLowerCase();
      return billId.contains(q) ||
          table.contains(q) ||
          doc.id.toLowerCase().contains(q);
    }).toList();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50 &&
        !isLoading &&
        hasMore) {
      fetchTransactions();
    }
  }

  static final DateFormat _dateTimeLabelFormat = DateFormat(
    "dd-MM-yyyy hh:mm a",
  );

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final base = isFrom ? (fromDate ?? now) : (toDate ?? fromDate ?? now);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: isFrom ? DateTime(2023) : (fromDate ?? DateTime(2023)),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;

    // Automatically follow up with a time picker so the user can filter by an
    // exact date and time.
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;

    // If the time picker is dismissed, fall back to the day's boundary time so
    // a date-only selection still behaves sensibly.
    final time =
        pickedTime ??
        (isFrom
            ? const TimeOfDay(hour: 0, minute: 0)
            : const TimeOfDay(hour: 23, minute: 59));

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
      isFrom ? 0 : 59,
      isFrom ? 0 : 999,
    );

    setState(() {
      if (isFrom) {
        fromDate = selected;
        fromController.text = _dateTimeLabelFormat.format(selected);

        // If toDate not selected, default to today's end-of-day.
        if (toDate == null) {
          final endOfToday = DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
            999,
          );
          toDate = endOfToday;
          toController.text = _dateTimeLabelFormat.format(endOfToday);
        }
      } else {
        // If user picks To and From is null, default From to start of that day.
        if (fromDate == null) {
          final startOfDay = DateTime(
            selected.year,
            selected.month,
            selected.day,
            0,
            0,
            0,
          );
          fromDate = startOfDay;
          fromController.text = _dateTimeLabelFormat.format(startOfDay);
        }
        toDate = selected;
        toController.text = _dateTimeLabelFormat.format(selected);
      }
    });

    // apply filter automatically after selection
    _applyFilter();
  }

  void _applyFilter() async {
    if (fromDate != null) {
      final now = DateTime.now();
      // Use the exact selected date & time so the totals match the filtered
      // transaction list (and the Excel export) for the same range.
      final effectiveFrom = fromDate!;
      final effectiveTo =
          toDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      // Sum the actual transactions in the precise range.
      final result = await getRevenueBetweenDates(effectiveFrom, effectiveTo);

      setState(() {
        grandTotal = result["totalRevenue"];
        grandTotalOnline = result["totalOnline"];
        grandTotalCash = result["totalCash"];
        grandTotalDiscount = result["totalDiscount"];
        totalTransactionsData = result["totalTransactions"];
        // reset pagination
        transactions.clear();
        lastDoc = null;
        hasMore = true;
      });

      // fetch first page for this filter
      fetchTransactions();
    }
  }

  /// Sums the actual transactions whose `createdAt` falls within the exact
  /// [from]..[to] window. This keeps the totals consistent with the filtered
  /// transaction list and the Excel export (which both filter by exact time),
  /// rather than the day-granular `daily_stats` aggregates.
  Future<Map<String, dynamic>> getRevenueBetweenDates(
    DateTime from,
    DateTime to,
  ) async {
    final snapshot = await FirestorePaths
        .scoped('transactions')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();

    double totalRevenue = 0;
    double totalCash = 0;
    double totalOnline = 0;
    double totalDiscount = 0;
    int totalTransactions = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalRevenue += (data["total"] as num?)?.toDouble() ?? 0.0;
      totalCash += (data["cashAmount"] as num?)?.toDouble() ?? 0.0;
      totalOnline += (data["onlineAmount"] as num?)?.toDouble() ?? 0.0;
      totalDiscount += (data["discount"] as num?)?.toDouble() ?? 0.0;
      totalTransactions += 1;
    }

    return {
      "totalRevenue": totalRevenue,
      "totalCash": totalCash,
      "totalOnline": totalOnline,
      "totalDiscount": totalDiscount,
      "totalTransactions": totalTransactions,
    };
  }

  Future<void> _reloadAfterTransactionEdit() async {
    setState(() {
      transactions.clear();
      lastDoc = null;
      hasMore = true;
    });
    // Always reload totals from the selected date range (never all-time).
    if (fromDate != null) {
      final now = DateTime.now();
      final effectiveFrom = fromDate!;
      final effectiveTo =
          toDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final result =
          await getRevenueBetweenDates(effectiveFrom, effectiveTo);
      if (!mounted) return;
      setState(() {
        grandTotal = result['totalRevenue'];
        grandTotalOnline = result['totalOnline'];
        grandTotalCash = result['totalCash'];
        grandTotalDiscount = result['totalDiscount'];
        totalTransactionsData = result['totalTransactions'];
      });
    }
    await fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    if (isLoading || !hasMore) return;
    // Date range is required; never load the full collection.
    if (fromDate == null) return;

    setState(() => isLoading = true);

    final now = DateTime.now();
    final effectiveFrom = fromDate!;
    final effectiveTo =
        toDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    Query<Map<String, dynamic>> query = FirestorePaths
        .scoped('transactions')
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveFrom),
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: Timestamp.fromDate(effectiveTo),
        )
        .orderBy("createdAt", descending: true);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc!);
    }

    query = query.limit(pageSize);

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        transactions.addAll(snapshot.docs);
        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) {
          hasMore = false;
        }
      });
    } else {
      setState(() => hasMore = false);
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        elevation: 0,
        titleSpacing: 16,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Expanded(
              child: Text(
                totalTransactionsData != 0
                    ? "Transactions ($totalTransactionsData)"
                    : "Transactions",
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: fontMulishBold,
                  color: Colors.white,
                ),
              ),
            ),
            // Online total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "₹${grandTotalOnline.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishSemiBold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cash total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_rupee, color: Colors.white70, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    grandTotalCash.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: fontMulishSemiBold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "From Date & Time",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.event_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: fontMulishSemiBold),
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: toController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "To Date & Time",
                      labelStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontFamily: fontMulishRegular,
                      ),
                      prefixIcon: const Icon(Icons.event_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1A3A5C), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(fontSize: 14, fontFamily: fontMulishSemiBold),
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by Bill ID, table, or reference...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFf57c35), width: 1.5),
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontFamily: fontMulishSemiBold,
              ),
            ),
          ),

          // Grouped list (unchanged layout, paginated)
          Expanded(
            child: transactions.isEmpty && isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No transactions found'
                          : 'No transactions match "$_searchQuery"',
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredTransactions.length + 1,
                    itemBuilder: (context, index) {
                      if (index < _filteredTransactions.length) {
                        final doc = _filteredTransactions[index];
                        final data = doc.data();
                        final tableName = data['table'] ?? 'Unknown';
                        final billId = TransactionBillService.displayBillId(
                          data,
                          documentId: doc.id,
                        );
                        final cashAmount = (data["cashAmount"] as int?) ?? 0;
                        final onlineAmount =
                            (data["onlineAmount"] as int?) ?? 0;
                        final total =
                            (data["total"] as num?)?.toDouble() ?? 0.0;
                        final discount =
                            (data["discount"] as num?)?.toDouble() ?? 0.0;
                        final dateTime = (data["createdAt"] as Timestamp?)
                            ?.toDate();
                        final completedBy =
                            (data['completedBy']?.toString() ?? '').trim();
                        final dateKey = dateTime != null
                            ? DateFormat("dd-MM-yyyy").format(dateTime)
                            : "Unknown Date";

                        // show date header for first item or when date changes
                        bool showDateHeader = true;
                        if (index > 0) {
                          final prevData = _filteredTransactions[index - 1].data();
                          final prevDateTime =
                              (prevData["createdAt"] as Timestamp?)?.toDate();
                          final prevDateKey = prevDateTime != null
                              ? DateFormat("dd-MM-yyyy").format(prevDateTime)
                              : "Unknown Date";
                          if (prevDateKey == dateKey) {
                            showDateHeader = false;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date group header
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A3A5C),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              color: Colors.white70, size: 12),
                                          const SizedBox(width: 6),
                                          Text(
                                            dateKey,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: fontMulishBold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Divider(
                                          color: Colors.grey.shade300,
                                          thickness: 1),
                                    ),
                                  ],
                                ),
                              ),
                            InkWell(
                              onTap: () async {
                                final result =
                                    await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailsPage(
                                      transactionId: doc.id,
                                      transaction: data,
                                    ),
                                  ),
                                );
                                if (result != null && mounted) {
                                  if (result['deleted'] == true ||
                                      result.containsKey('transaction')) {
                                    await _reloadAfterTransactionEdit();
                                  }
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(
                                    left: BorderSide(
                                      color: cashAmount > 0 && onlineAmount > 0
                                          ? Colors.purple.shade300
                                          : onlineAmount > 0
                                              ? Colors.blue.shade400
                                              : const Color(0xFFf57c35),
                                      width: 4,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Table icon
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A3A5C).withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.table_restaurant_outlined,
                                        size: 18,
                                        color: Color(0xFF1A3A5C),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tableName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontFamily: fontMulishBold,
                                              color: Color(0xFF1A3A5C),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            billId,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontFamily: fontMulishSemiBold,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            dateTime != null
                                                ? DateFormat('hh:mm a').format(dateTime)
                                                : "-",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                              fontFamily: fontMulishRegular,
                                            ),
                                          ),
                                          if (completedBy.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'Completed By: $completedBy',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontFamily: fontMulishSemiBold,
                                              ),
                                            ),
                                          ],
                                          // Payment pills
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              if (onlineAmount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.blue.shade200),
                                                  ),
                                                  child: Text(
                                                    "Online ₹$onlineAmount",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: fontMulishSemiBold,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ),
                                                ),
                                              if (cashAmount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.green.shade200),
                                                  ),
                                                  child: Text(
                                                    "Cash ₹$cashAmount",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: fontMulishSemiBold,
                                                      color: Colors.green.shade700,
                                                    ),
                                                  ),
                                                ),
                                              if (discount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.red.shade200),
                                                  ),
                                                  child: Text(
                                                    "Discount ₹${discount.toStringAsFixed(0)}",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: fontMulishSemiBold,
                                                      color: Colors.red.shade700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Total amount + discount
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "₹${total.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontFamily: fontMulishBold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        if (discount > 0) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "-₹${discount.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: fontMulishSemiBold,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // loader / no more
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: hasMore
                                ? const CircularProgressIndicator()
                                : const Text("No more transactions"),
                          ),
                        );
                      }
                    },
                  ),
          ),

          // Grand Total + Total Discount bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1A3A5C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Discount",
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: fontMulishSemiBold,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        "₹${grandTotalDiscount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: fontMulishBold,
                          color: Color(0xFFFF8A80),
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Grand Total",
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: fontMulishSemiBold,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      "₹${grandTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: fontMulishBold,
                        color: Color(0xFFf57c35),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
