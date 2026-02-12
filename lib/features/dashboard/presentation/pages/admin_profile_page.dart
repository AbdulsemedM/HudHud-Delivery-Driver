import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hudhud_delivery_driver/core/di/service_locator.dart';
import 'package:hudhud_delivery_driver/core/routes/app_router.dart';
import 'package:hudhud_delivery_driver/core/services/secure_storage_service.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  String? _name;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final storage = getIt<SecureStorageService>();
    final name = await storage.getUserName();
    final email = await storage.getUserEmail();
    if (mounted) setState(() {
      _name = name;
      _email = email;
    });
  }

  Future<void> _logout() async {
    await getIt<SecureStorageService>().clearAll();
    if (mounted) context.goNamed(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_name != null || _email != null)
            Card(
              child: ListTile(
                title: Text(_name ?? 'Admin'),
                subtitle: Text(_email ?? ''),
              ),
            ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            onTap: () {
              // TODO: change password screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
