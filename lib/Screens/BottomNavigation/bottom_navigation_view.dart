import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/AddCategoryPage.dart';
import 'package:demo/AddTablePage.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/TransactionsPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../KitchenOrdersListView.dart';
import '../../DragDropTables.dart';
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
    TransactionsPage(),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: userRole == "Admin"
            ? tabsForAdmin[_currentIndex]
            : tabsForStaff[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: primary_color,
          unselectedItemColor: silver_9393aa,
          selectedLabelStyle: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 11,
            color: primary_color,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: fontMulishSemiBold,
            fontSize: 11,
            color: silver_9393aa,
          ),
          currentIndex: _currentIndex,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 6,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                icon_dashboard,
                width: 25,
                height: 25,
                color: silver_9393aa,
              ),
              activeIcon: SvgPicture.asset(
                icon_dashboard,
                width: 25,
                height: 25,
                color: primary_color,
              ),
              label: "Dashboard",
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                icon_table,
                width: 25,
                height: 25,
                color: silver_9393aa,
              ),
              activeIcon: SvgPicture.asset(
                icon_table,
                width: 25,
                height: 25,
                color: primary_color,
              ),
              label: "Table",
            ),

            if (userRole == "Admin")
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  icon_menu,
                  width: 25,
                  height: 25,
                  color: silver_9393aa,
                ),
                activeIcon: SvgPicture.asset(
                  icon_menu,
                  width: 25,
                  height: 25,
                  color: primary_color,
                ),
                label: "Menu",
              ),
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                icon_cooking,
                width: 25,
                height: 25,
                color: silver_9393aa,
              ),
              activeIcon: SvgPicture.asset(
                icon_menu,
                width: 25,
                height: 25,
                color: primary_color,
              ),
              label: "Kitchen",
            ),
            // BottomNavigationBarItem(
            //   icon: SvgPicture.asset(
            //     icon_payouts,
            //     width: 25,
            //     height: 25,
            //     color: silver_9393aa,
            //   ),
            //   activeIcon: SvgPicture.asset(
            //     icon_payouts,
            //     width: 25,
            //     height: 25,
            //     color: blue_3093bb,
            //   ),
            //   label: "Payouts",
            // ),
            if (userRole == "Admin")
              BottomNavigationBarItem(
                icon: SvgPicture.asset(
                  icon_transaction,
                  width: 25,
                  height: 25,
                  color: silver_9393aa,
                ),
                activeIcon: SvgPicture.asset(
                  icon_transaction,
                  width: 25,
                  height: 25,
                  color: primary_color,
                ),
                label: "Transactions",
              ),
          ],
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
