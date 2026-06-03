import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/Screens/Settings/SettingsPage.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../KitchenOrdersListView.dart';
import '../../DragDropTables.dart';

class BottomNavigationView extends StatefulWidget {
  const BottomNavigationView({Key? key}) : super(key: key);

  @override
  State<BottomNavigationView> createState() => _BottomNavigationViewState();
}

class _BottomNavigationViewState extends State<BottomNavigationView> {
  int _currentIndex = 0;

  String? userRole;

  static const int _kitchenTabIndex = 1;

  List<Widget> _buildTabs() => [
        const DragListBetweenTables(),
        KitchenOrdersListView(isTabActive: _currentIndex == _kitchenTabIndex),
        const SettingsPage(),
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
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  static const _navy = Color(0xFF1A3A5C);
  static const _orange = Color(0xFFf57c35);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: IndexedStack(
          index: _currentIndex,
          children: _buildTabs(),
        ),
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded, size: 24),
                activeIcon: Icon(Icons.grid_view_rounded, size: 26),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.soup_kitchen_rounded, size: 24),
                activeIcon: Icon(Icons.soup_kitchen_rounded, size: 26),
                label: 'Kitchen',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded, size: 24),
                activeIcon: Icon(Icons.settings_rounded, size: 26),
                label: 'Settings',
              ),
            ],
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}
