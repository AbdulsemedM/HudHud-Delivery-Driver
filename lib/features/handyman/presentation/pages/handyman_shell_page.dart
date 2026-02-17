import 'package:flutter/material.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_earnings_tab.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_home_tab.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_profile_tab.dart';
import 'package:hudhud_delivery_driver/features/handyman/presentation/pages/handyman_requests_tab.dart';

class HandymanShellPage extends StatefulWidget {
  const HandymanShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HandymanShellPage> createState() => _HandymanShellPageState();
}

class _HandymanShellPageState extends State<HandymanShellPage> {
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
        children: const [
          HandymanHomeTab(),
          HandymanRequestsTab(),
          HandymanEarningsTab(),
          HandymanProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: onSelectTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
