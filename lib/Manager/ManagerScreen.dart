import 'package:canteendesk/Manager/ManagerOrders.dart';
import 'package:canteendesk/Manager/ManagerPayment.dart';
import 'package:canteendesk/Manager/ManagerProfile.dart';
import 'package:canteendesk/Manager/ManagerSettings.dart';
import 'package:flutter/material.dart';
import 'ManagerHome.dart';
import 'ManagerReport.dart';
import 'ManagerMenu.dart';

class ManagerScreen extends StatefulWidget {
  @override
  _ManagerScreenState createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
     ManagerHome(),
     ManagerReport(),
     ManagerOrders(),
     ManagerMenu(),
     ManagerPayment(),
     ManagerProfile(),
     ManagerSettings(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 80,
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
              unselectedIconTheme: IconThemeData(color: Colors.grey[600]),
              selectedLabelTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(color: Colors.grey[600]),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.report), label: Text('Reports')),
                NavigationRailDestination(icon: Icon(Icons.shopping_cart), label: Text('Orders')),
                NavigationRailDestination(icon: Icon(Icons.restaurant_menu), label: Text('Manage Menu')),
                NavigationRailDestination(icon: Icon(Icons.payment), label: Text('Manage Payment')),
                NavigationRailDestination(icon: Icon(Icons.person), label: Text('Profile')),
                NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
              ],
            ),
          ),
          const VerticalDivider(width: 2, thickness: 2, color: Colors.grey),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  color: Color(0xFFF7F3F9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
                        ),
                        child: Text("Canteen Manager", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: Icon(Icons.notifications, color: Colors.black),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

