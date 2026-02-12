import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/dashboard/presentation/pages/dashboard_overview_page.dart';
import 'package:hudhud_delivery_driver/features/admin_users/presentation/pages/drivers_list_page.dart';
import 'package:hudhud_delivery_driver/features/admin_users/presentation/pages/couriers_list_page.dart';
import 'package:hudhud_delivery_driver/features/admin_users/presentation/pages/handymen_list_page.dart';
import 'package:hudhud_delivery_driver/features/dashboard/presentation/pages/admin_profile_page.dart';

class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void onSelectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardOverviewPage(onNavigateToTab: onSelectTab),
          const DriversListPage(),
          const CouriersListPage(),
          const HandymenListPage(),
          const AdminProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: onSelectTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Drivers'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Couriers'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Handymen'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
