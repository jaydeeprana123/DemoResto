import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo/Screens/Transactions/repositories/transactions_repository.dart';

/// TransactionsController
/// 
/// Part of the GetX Controller Pattern.
/// Oversees reactive state changes, date filtering, pagination, and data synchronization for the transactions ledger.
class TransactionsController extends GetxController {
  final TransactionsRepository _repository = TransactionsRepository();

  final Rxn<DateTime> fromDate = Rxn<DateTime>();
  final Rxn<DateTime> toDate = Rxn<DateTime>();

  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  final RxBool isFilterApplied = false.obs;
  final RxDouble grandTotal = 0.0.obs;
  final RxDouble grandTotalOnline = 0.0.obs;
  final RxDouble grandTotalCash = 0.0.obs;
  final RxInt totalTransactionsData = 0.obs;

  final RxList<Map<String, dynamic>> transactions = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  
  DocumentSnapshot? _lastDoc;
  static const int pageSize = 10;
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    loadAllTimeRevenue();
    fetchNextPage();
    scrollController.addListener(_scrollListener);
  }

  @override
  void onClose() {
    scrollController.dispose();
    fromController.dispose();
    toController.dispose();
    super.onClose();
  }

  void _scrollListener() {
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 50 &&
        !isLoading.value &&
        hasMore.value) {
      fetchNextPage();
    }
  }

  /// Fetches total lifetime revenue from the daily_stats collection via repository.
  Future<void> loadAllTimeRevenue() async {
    try {
      final result = await _repository.getTotalRevenue();
      isFilterApplied.value = false;
      grandTotal.value = result["totalRevenue"];
      grandTotalOnline.value = result["totalOnline"];
      grandTotalCash.value = result["totalCash"];
      totalTransactionsData.value = result["totalTransactions"];
    } catch (e) {
      Get.snackbar("Error", "Failed to load revenue stats: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }

  /// Formulates parameters to filter transactions by date and invokes repository retrieval.
  Future<void> applyDateFilter() async {
    final from = fromDate.value;
    if (from == null) return;

    final now = DateTime.now();
    final effectiveFrom = DateTime(from.year, from.month, from.day, 0, 0, 0);
    final to = toDate.value;
    final effectiveTo = (to != null)
        ? DateTime(to.year, to.month, to.day, 23, 59, 59, 999)
        : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    try {
      final result = await _repository.getRevenueBetweenDates(effectiveFrom, effectiveTo);
      isFilterApplied.value = true;
      grandTotal.value = result["totalRevenue"];
      grandTotalOnline.value = result["totalOnline"];
      grandTotalCash.value = result["totalCash"];
      totalTransactionsData.value = result["totalTransactions"];
      
      // Reset pagination for the filtered list
      transactions.clear();
      _lastDoc = null;
      hasMore.value = true;
      await fetchNextPage();
    } catch (e) {
      Get.snackbar("Error", "Failed to apply date filter: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }

  /// Appends next batch of transactions from Firestore.
  Future<void> fetchNextPage() async {
    if (isLoading.value || !hasMore.value) return;

    isLoading.value = true;

    try {
      final snapshot = await _repository.fetchTransactions(
        fromDate: fromDate.value,
        toDate: toDate.value,
        isFilterApplied: isFilterApplied.value,
        lastDoc: _lastDoc,
        limit: pageSize,
      );

      if (snapshot.docs.isNotEmpty) {
        final newItems = snapshot.docs.map((doc) {
          return {
            "id": doc.id,
            ...doc.data(),
          };
        }).toList();
        
        transactions.addAll(newItems);
        _lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) {
          hasMore.value = false;
        }
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch transactions: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// Displays date picker controls and resets transaction filters.
  Future<void> pickDate({required BuildContext context, required bool isFrom}) async {
    final now = DateTime.now();
    final initialDate = isFrom 
        ? (fromDate.value ?? now) 
        : (toDate.value ?? fromDate.value ?? now);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isFrom ? DateTime(2023) : (fromDate.value ?? DateTime(2023)),
      lastDate: now,
    );

    if (picked != null) {
      if (isFrom) {
        fromDate.value = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        fromController.text = DateFormat("dd-MM-yyyy").format(picked);

        if (toDate.value == null) {
          toDate.value = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          toController.text = DateFormat("dd-MM-yyyy").format(now);
        }
      } else {
        if (fromDate.value == null) {
          fromDate.value = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
          fromController.text = DateFormat("dd-MM-yyyy").format(picked);
        }
        toDate.value = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
        toController.text = DateFormat("dd-MM-yyyy").format(picked);
      }
      await applyDateFilter();
    }
  }

  /// Communicates with repository to update a transaction record.
  Future<void> updateTransactionRecord(String docId, Map<String, dynamic> oldTx, Map<String, dynamic> newTx) async {
    try {
      await _repository.updateTransaction(docId, oldTx, newTx);
      
      // Update local item in list to reflect changes immediately
      final idx = transactions.indexWhere((element) => element["id"] == docId);
      if (idx != -1) {
        transactions[idx] = {
          "id": docId,
          ...newTx,
        };
      }
      
      // Recalculate filter/totals to show current info
      if (isFilterApplied.value) {
        await applyDateFilter();
      } else {
        await loadAllTimeRevenue();
      }

      Get.snackbar("Success", "Transaction updated successfully",
          backgroundColor: Colors.green.shade700, colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", "Failed to update transaction: $e",
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
    }
  }
}
