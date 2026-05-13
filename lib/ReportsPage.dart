import 'package:flutter/material.dart';
import 'TransactionsPage.dart';
import 'ExpensePage.dart';
import 'Styles/my_font.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: const Color(0xFF1A3A5C),
            child: const TabBar(
              indicatorColor: Color(0xFFf57c35),
              indicatorWeight: 3,
              labelColor: Color(0xFFf57c35),
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontFamily: fontMulishBold, fontSize: 15),
              tabs: [
                Tab(text: "Income"),
                Tab(text: "Expenses"),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                TransactionsPage(),
                ExpensePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
