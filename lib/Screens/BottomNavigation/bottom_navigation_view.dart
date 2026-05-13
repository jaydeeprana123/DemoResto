import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart';
import 'package:demo/AddTablePage.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/ReportsPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../KitchenOrdersListView.dart';
import '../../Screens/Dashboard/DragDropTables.dart';
import '../../Styles/my_icons.dart';

class BottomNavigationView extends StatefulWidget {
  const BottomNavigationView({Key? key}) : super(key: key);

  @override
  State<BottomNavigationView> createState() => _BottomNavigationViewState();
}

class _BottomNavigationViewState extends State<BottomNavigationView> {
  int _currentIndex = 0;

  String? userRole;

  final tabsForAdmin = [
    DragListBetweenTables(),
    AddTablePage(),
    AddCategoryPage(),
    KitchenOrdersListView(),
    const ReportsPage(),
  ];

  final tabsForStaff = [
    DragListBetweenTables(),
    AddTablePage(),
    KitchenOrdersListView(),
  ];

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      userRole = userDoc.data()?['role'];
      print('User role: $userRole');
      setState(() {}); // Update UI
    }
  }

  @override
  void initState() {
    super.initState();

    _loadUserRole();
  }

  // ── Brand colours ────────────────────────────────────────────────────────
  static const _navy   = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    final isAdmin = userRole == "Admin";
    final tabs   = isAdmin ? tabsForAdmin : tabsForStaff;

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: tabs[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _navy,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            backgroundColor: _navy,
            selectedItemColor: _orange,
            unselectedItemColor: Colors.white54,
            selectedLabelStyle: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: fontMulishSemiBold,
              fontSize: 11,
            ),
            currentIndex: _currentIndex,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            items: [
              // Dashboard — always shown
              const BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded, size: 24),
                activeIcon: Icon(Icons.grid_view_rounded, size: 26),
                label: "Dashboard",
              ),
              // Table — always shown
              const BottomNavigationBarItem(
                icon: Icon(Icons.table_restaurant_rounded, size: 24),
                activeIcon: Icon(Icons.table_restaurant_rounded, size: 26),
                label: "Table",
              ),
              // Menu — Admin only
              if (isAdmin)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book_rounded, size: 24),
                  activeIcon: Icon(Icons.menu_book_rounded, size: 26),
                  label: "Menu",
                ),
              // Kitchen — always shown
              const BottomNavigationBarItem(
                icon: Icon(Icons.soup_kitchen_rounded, size: 24),
                activeIcon: Icon(Icons.soup_kitchen_rounded, size: 26),
                label: "Kitchen",
              ),
              // Reports (Transactions & Expenses) — Admin only
              if (isAdmin)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_rounded, size: 24),
                  activeIcon: Icon(Icons.analytics_rounded, size: 26),
                  label: "Reports",
                ),
            ],
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}
