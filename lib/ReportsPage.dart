import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'TransactionsPage.dart';
import 'ExpensePage.dart';
import 'Styles/my_font.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({Key? key}) : super(key: key);

  static const Color _navy = Color(0xFF1A3A5C);
  static const Color _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Reports",
            style: TextStyle(fontFamily: fontMulishBold, color: _navy, fontSize: 18),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              color: Colors.white,
              child: TabBar(
                indicatorColor: _orange,
                indicatorWeight: 3,
                labelColor: _navy,
                unselectedLabelColor: Colors.grey.shade400,
                labelStyle: const TextStyle(fontFamily: fontMulishBold, fontSize: 14),
                tabs: const [
                  Tab(text: "INCOME"),
                  Tab(text: "EXPENSES"),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            TransactionsPage(),
            ExpensePage(),
          ],
        ),
      ),
    );
  }
}
