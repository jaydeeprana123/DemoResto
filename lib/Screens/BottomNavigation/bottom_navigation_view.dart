import 'package:demo/AddCategoryPage.dart';
import 'package:demo/Styles/my_colors.dart';
import 'package:demo/Styles/my_font.dart';
import 'package:demo/TransactionsPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

import '../../AllOrdersPage.dart';
import '../../DragDropTables.dart';
import '../../Styles/my_icons.dart';

class BottomNavigationView extends StatefulWidget {
  const BottomNavigationView({Key? key}) : super(key: key);

  @override
  State<BottomNavigationView> createState() => _BottomNavigationViewState();
}

class _BottomNavigationViewState extends State<BottomNavigationView> {
  int _currentIndex = 0;
  final tabs = [
    DragListBetweenTables(),
    AddCategoryPage(),
    OrdersGroupedListPage(),
    TransactionsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: tabs[_currentIndex],
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
