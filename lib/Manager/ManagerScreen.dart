import 'package:shared_preferences/shared_preferences.dart';
import 'package:canteendesk/Login/LoginScreen.dart';
import 'package:canteendesk/Manager/ManagerOrders.dart';
import 'package:canteendesk/Manager/ManagerPayment.dart';
import 'package:canteendesk/Manager/ManagerProfile.dart';
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
     ManagerManageMenu(),
     ManagerPaymentMethods(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  void _showProfileMenu(Offset tapPosition) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx +40,
        tapPosition.dy + 10,
        overlay.size.width - (tapPosition.dx + 40),
        overlay.size.height -( tapPosition.dy + 10),
      ),
      items: const [
         PopupMenuItem<String>(
          value: 'personal_information',
          child: ListTile(
            leading: Icon(Icons.person),
            title: Text('Personal Information'),
          ),
        ),
         PopupMenuDivider(),
         PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
          ),
        ),
         PopupMenuDivider(),
         PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
          ),
        ),
      ],
    );

    switch (selected) {
      case 'personal_information':
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ManagerProfile()),
      );
        break;
      case 'settings':
        // Handle settings
        break;
      case 'logout':
        final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false); // Clear login state

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false, // Remove all routes
      );// Handle logout
        break;
    }
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
                  GestureDetector(
                     onTapDown: (TapDownDetails details) {
                       _showProfileMenu(details.globalPosition);
                     },
                     child: const Padding(
                       padding: EdgeInsets.symmetric(horizontal: 8.0),
                       child: Icon(Icons.person, color: Colors.black),
                    ),
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

